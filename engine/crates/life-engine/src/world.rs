//! The world: cells, one epoch of the substrate's rule, the observables, snapshots and
//! rendering. A run is fully determined by `(params, seed)` — every draw comes from a
//! stream keyed by the seed and the epoch, so a world restored from a snapshot continues
//! exactly as the uninterrupted run would have.

use crate::bff;
use crate::hash::fnv1a64;
use crate::metrics::{self, Metrics, TransitionTracker};
use crate::params::{Init, ParamError, Params, Substrate};
use crate::render;
use crate::replicator;
use crate::rng::{self, Rng};
use crate::snapshot::{self, SnapshotError};

const STREAM_INIT: u64 = 0;
const STREAM_STEP: u64 = 1;
const STREAM_REPLICATOR: u64 = 2;

#[derive(Debug, Clone)]
pub struct World {
    params: Params,
    seed: u64,
    epoch: u64,
    cells: Vec<u8>,
    /// Where `step_life` writes the next generation before swapping it into `cells`;
    /// never part of the world's state, so it stays out of `world_hash` and snapshots.
    /// Empty for the soup, which rewrites its cells in place.
    scratch: Vec<u8>,
    transition: TransitionTracker,
    /// The `copy_rate` of the most recently counted epoch; see `step_soup`.
    copy_rate: f64,
}

impl World {
    pub fn new(params: &Params, seed: u64) -> Result<Self, ParamError> {
        params.validate()?;
        let mut world = Self {
            params: params.clone(),
            seed,
            epoch: 0,
            cells: vec![0; params.cell_count() * params.stride()],
            scratch: life_scratch(params),
            transition: TransitionTracker::default(),
            copy_rate: 0.0,
        };
        if params.init == Init::Random {
            let mut rng = rng::seeded(seed, STREAM_INIT, 0);
            let alphabet = world.params.substrate;
            for byte in &mut world.cells {
                *byte = draw_cell_byte(&mut rng, alphabet);
            }
        }
        Ok(world)
    }

    pub fn params(&self) -> &Params {
        &self.params
    }

    pub fn seed(&self) -> u64 {
        self.seed
    }

    pub fn epoch(&self) -> u64 {
        self.epoch
    }

    pub fn width(&self) -> u32 {
        self.params.width
    }

    pub fn height(&self) -> u32 {
        self.params.height
    }

    /// The state of one cell: a whole tape in the soup, one `0`/`1` byte in life.
    pub fn cell(&self, x: u32, y: u32) -> &[u8] {
        let stride = self.params.stride();
        let at = self.index(x, y) * stride;
        &self.cells[at..at + stride]
    }

    /// Panics unless `bytes` is exactly one cell wide; callers know the stride.
    pub fn set_cell(&mut self, x: u32, y: u32, bytes: &[u8]) {
        let stride = self.params.stride();
        assert_eq!(bytes.len(), stride, "a cell holds {stride} bytes");
        let at = self.index(x, y) * stride;
        self.cells[at..at + stride].copy_from_slice(bytes);
    }

    /// One epoch: every cell interacts once, then every byte mutates with probability
    /// `mutation_rate`.
    pub fn step(&mut self) {
        let mut rng = rng::seeded(self.seed, STREAM_STEP, self.epoch);
        match self.params.substrate {
            Substrate::Soup => self.step_soup(&mut rng),
            Substrate::Life => self.step_life(),
        }
        self.mutate(&mut rng);
        self.epoch += 1;
    }

    /// Every observable of the design, and the transition tracker fed by this sample.
    pub fn metrics(&mut self) -> Metrics {
        let compressed = metrics::compress_ratio(&self.cells);
        self.sample(compressed)
    }

    /// The same sample as `metrics` and the same snapshot as `snapshot`, taken together
    /// at an epoch whose cadences coincide: `compress_ratio` and the snapshot's payload
    /// are one and the same zlib stream over the cells, so it is produced once.
    pub fn metrics_with_snapshot(&mut self) -> (Metrics, Vec<u8>) {
        let payload = metrics::compress(&self.cells);
        let compressed = metrics::compress_ratio_of(payload.len(), self.cells.len());
        let measured = self.sample(compressed);
        (
            measured,
            snapshot::encode_compressed(&self.snapshot_header(), &payload),
        )
    }

    pub fn transition_epoch(&self) -> Option<u64> {
        self.transition.epoch()
    }

    pub fn world_hash(&self) -> u64 {
        fnv1a64(&self.cells)
    }

    pub fn snapshot(&self) -> Vec<u8> {
        snapshot::encode(&self.snapshot_header(), &self.cells)
    }

    fn snapshot_header(&self) -> snapshot::Header {
        snapshot::Header {
            substrate: self.params.substrate,
            width: self.params.width,
            height: self.params.height,
            tape_len: self.params.tape_len,
            epoch: self.epoch,
            transition: self.transition.state(),
        }
    }

    pub fn from_snapshot(params: &Params, seed: u64, bytes: &[u8]) -> Result<Self, SnapshotError> {
        let (header, cells) = snapshot::decode(params, bytes)?;
        Ok(Self {
            params: params.clone(),
            seed,
            epoch: header.epoch,
            cells,
            scratch: life_scratch(params),
            transition: TransitionTracker::from_state(header.transition),
            copy_rate: 0.0,
        })
    }

    /// Fills `buf` with `width × height` RGBA pixels, top-left first.
    pub fn render_rgba(&self, buf: &mut [u8]) {
        let pixels = self.params.cell_count();
        assert_eq!(
            buf.len(),
            pixels * render::BYTES_PER_PIXEL,
            "the buffer must hold width × height RGBA pixels"
        );
        let stride = self.params.stride();
        let soup = self.params.substrate == Substrate::Soup;
        let (pixels, _) = buf.as_chunks_mut::<{ render::BYTES_PER_PIXEL }>();
        for (cell, pixel) in self.cells.chunks_exact(stride).zip(pixels) {
            let rgba = if soup {
                render::soup_pixel(cell, metrics::op_density(cell))
            } else {
                render::life_pixel(cell[0] != 0)
            };
            pixel.copy_from_slice(&rgba);
        }
    }

    fn index(&self, x: u32, y: u32) -> usize {
        let x = (x % self.params.width) as usize;
        let y = (y % self.params.height) as usize;
        y * self.params.width as usize + x
    }

    /// One epoch of the soup, and — on the epochs a sample will read — the `copy_rate`
    /// of those interactions. Counting costs one extra `2 × stride` copy and at most three
    /// comparisons per interaction, so it is off on every other epoch.
    fn step_soup(&mut self, rng: &mut Rng) {
        let stride = self.params.stride();
        let max_steps = self.params.max_steps;
        let ops = self.params.op_set();
        let counting = self.counts_copies();
        let mut order: Vec<u32> = (0..self.params.cell_count() as u32).collect();
        rng::shuffle(&mut order, rng);

        let mut pair = vec![0u8; stride * 2];
        let mut before = vec![0u8; stride * 2];
        let mut interactions: u64 = 0;
        let mut copies: u64 = 0;
        for cell in &order {
            let a = *cell as usize;
            let b = self.pick_partner(a, rng);
            if a == b {
                continue;
            }
            pair[..stride].copy_from_slice(&self.cells[a * stride..a * stride + stride]);
            pair[stride..].copy_from_slice(&self.cells[b * stride..b * stride + stride]);
            if counting {
                before.copy_from_slice(&pair);
            }
            bff::run_with(&mut pair, max_steps, ops);
            if counting {
                interactions += 1;
                // Two halves that arrived identical cannot show a copy: they already end
                // equal to each other's pre-execution tape whether or not anything ran, and
                // counting them reads 1.0 on a frozen monoculture.
                let copied = before[..stride] != before[stride..]
                    && (pair[stride..] == before[..stride] || pair[..stride] == before[stride..]);
                copies += u64::from(copied);
            }
            self.cells[a * stride..a * stride + stride].copy_from_slice(&pair[..stride]);
            self.cells[b * stride..b * stride + stride].copy_from_slice(&pair[stride..]);
        }
        if counting {
            self.copy_rate = if interactions == 0 {
                0.0
            } else {
                copies as f64 / interactions as f64
            };
        }
    }

    /// True when the epoch this step is about to produce is one `sample_every` will read,
    /// so `copy_rate` always describes the interactions immediately before the sample.
    fn counts_copies(&self) -> bool {
        let sample_every = self.params.sample_every as u64;
        sample_every > 0 && (self.epoch + 1).is_multiple_of(sample_every)
    }

    /// A uniformly chosen other cell within `radius`, or anywhere in the world when the
    /// radius is 0 (well-mixed). Wrapping can land on the cell itself in a world smaller
    /// than the neighbourhood; the caller skips that.
    fn pick_partner(&self, cell: usize, rng: &mut Rng) -> usize {
        let width = self.params.width as usize;
        let height = self.params.height as usize;
        let count = width * height;
        if self.params.radius == 0 {
            if count < 2 {
                return cell;
            }
            let mut other = rng::below(rng, count as u64 - 1) as usize;
            if other >= cell {
                other += 1;
            }
            return other;
        }

        let radius = self.params.radius as usize;
        let side = radius * 2 + 1;
        let centre = (side * side - 1) / 2;
        let mut offset = rng::below(rng, (side * side - 1) as u64) as usize;
        if offset >= centre {
            offset += 1;
        }
        let dx = (offset % side) as isize - radius as isize;
        let dy = (offset / side) as isize - radius as isize;
        let x = ((cell % width) as isize + dx).rem_euclid(width as isize) as usize;
        let y = ((cell / width) as isize + dy).rem_euclid(height as isize) as usize;
        y * width + x
    }

    /// `B3/S23` on a torus, in two sequential passes per row instead of eight scattered
    /// reads per cell: first each column's live count over the three rows around it, then
    /// a three-wide window over those sums. The sums are staged in the scratch row they
    /// then overwrite — the window reads one column ahead of the write, and column zero
    /// is kept aside for the wrap at the last column.
    fn step_life(&mut self) {
        let width = self.params.width as usize;
        let height = self.params.height as usize;
        let cells = &self.cells;
        let next = &mut self.scratch;
        for y in 0..height {
            let row = y * width;
            let above = if y == 0 { height - 1 } else { y - 1 } * width;
            let below = if y + 1 == height { 0 } else { y + 1 } * width;
            let above_row = &cells[above..above + width];
            let this_row = &cells[row..row + width];
            let below_row = &cells[below..below + width];
            let sums = &mut next[row..row + width];
            for (x, sum) in sums.iter_mut().enumerate() {
                *sum = u8::from(above_row[x] != 0)
                    + u8::from(this_row[x] != 0)
                    + u8::from(below_row[x] != 0);
            }
            let first = sums[0];
            let mut left = sums[width - 1];
            let mut mid = first;
            for x in 0..width {
                let right = if x + 1 == width { first } else { sums[x + 1] };
                let itself = this_row[x] != 0;
                let alive = left + mid + right - u8::from(itself);
                sums[x] = u8::from(alive == 3 || (itself && alive == 2));
                left = mid;
                mid = right;
            }
        }
        std::mem::swap(&mut self.cells, &mut self.scratch);
    }

    fn mutate(&mut self, rng: &mut Rng) {
        let rate = self.params.mutation_rate;
        if rate <= 0.0 {
            return;
        }
        let substrate = self.params.substrate;
        for byte in &mut self.cells {
            if rng::chance(rng, rate) {
                *byte = draw_cell_byte(rng, substrate);
            }
        }
    }

    fn sample(&mut self, compress_ratio: f64) -> Metrics {
        let measured = self.measure(compress_ratio);
        self.transition.observe(self.epoch, &measured);
        measured
    }

    fn measure(&self, compress_ratio: f64) -> Metrics {
        let stride = self.params.stride();
        let cells = self.params.cell_count() as f64;
        let ranked = metrics::ranked_tapes(&self.cells, stride);
        let top_share = ranked.first().map_or(0.0, |(_, n)| *n as f64 / cells);
        let histogram = metrics::ByteHistogram::of(&self.cells);

        Metrics {
            compress_ratio,
            distinct_tapes: ranked.len() as u64,
            top_share,
            op_density: histogram.op_density(),
            replicator_count: self.count_replicators(&ranked),
            entropy_bits: histogram.entropy_bits(),
            alphabet_size: histogram.alphabet_size(),
            copy_rate: self.copy_rate,
        }
    }

    /// Cells holding one of the `top_k` most common tapes that passes the replicator
    /// test. Life cells are single bits and have no replicator reading.
    fn count_replicators(&self, ranked: &[(&[u8], u64)]) -> u64 {
        if self.params.substrate != Substrate::Soup {
            return 0;
        }
        let mut rng = rng::seeded(self.seed, STREAM_REPLICATOR, self.epoch);
        let ops = self.params.op_set();
        ranked
            .iter()
            .take(self.params.top_k as usize)
            .filter(|(tape, _)| {
                replicator::is_replicator(tape, self.params.max_steps, ops, &mut rng)
            })
            .map(|(_, count)| *count)
            .sum()
    }
}

fn life_scratch(params: &Params) -> Vec<u8> {
    match params.substrate {
        Substrate::Life => vec![0; params.cell_count()],
        Substrate::Soup => Vec::new(),
    }
}

fn draw_cell_byte(rng: &mut Rng, substrate: Substrate) -> u8 {
    match substrate {
        Substrate::Soup => rng::byte(rng),
        Substrate::Life => rng::byte(rng) & 1,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Pinned so a change in the rules, the RNG or the visiting order cannot pass unseen:
    /// `Params::default()` at 32×32, seed 42, after 50 epochs.
    const PINNED_SOUP_HASH: u64 = 0xd25f_8c16_3d9e_2dd9;
    const PINNED_LIFE_HASH: u64 = 0x200a_f822_08b5_96b9;
    /// The same run with `,` ablated (DESIGN §1.3, sweep 5).
    const PINNED_ABLATED_SOUP_HASH: u64 = 0xb115_dbaa_f8d8_9bec;

    fn soup(width: u32, height: u32) -> Params {
        Params {
            width,
            height,
            ..Params::default()
        }
    }

    fn life(width: u32, height: u32) -> Params {
        Params {
            substrate: Substrate::Life,
            width,
            height,
            mutation_rate: 0.0,
            init: Init::Zero,
            ..Params::default()
        }
    }

    /// A soup the tracker can settle a transition on: every cell holds the same tape of
    /// 32 distinct bytes, none of them an instruction, so nothing executes and nothing
    /// writes. It reads compressible and still, with an alphabet well clear of the
    /// collapse guard — the zero-filled soup this once used reads an alphabet of one.
    fn quiet_diverse_soup(params: &Params) -> World {
        let mut world = World::new(params, 3).unwrap();
        let tape: Vec<u8> = (0..params.stride()).map(|at| 1 + (at % 32) as u8).collect();
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }
        world
    }

    fn stepped(params: &Params, seed: u64, epochs: u64) -> World {
        let mut world = World::new(params, seed).unwrap();
        for _ in 0..epochs {
            world.step();
        }
        world
    }

    /// One cell of `determinism_holds_across_the_parameter_matrix`: the same
    /// `(params, seed)` twice, another seed, and a snapshot taken halfway and resumed.
    fn assert_deterministic(params: &Params, seed: u64) {
        const EPOCHS: u64 = 20;
        let case = format!("{params:?} seed {seed}");

        let expected = stepped(params, seed, EPOCHS).world_hash();
        assert_eq!(
            stepped(params, seed, EPOCHS).world_hash(),
            expected,
            "two worlds from one (params, seed) diverged: {case}"
        );
        assert_ne!(
            stepped(params, seed + 100, EPOCHS).world_hash(),
            expected,
            "another seed reproduced the run: {case}"
        );

        let halfway = stepped(params, seed, EPOCHS / 2);
        let mut resumed = World::from_snapshot(params, seed, &halfway.snapshot()).unwrap();
        assert_eq!(resumed.epoch(), EPOCHS / 2, "{case}");
        for _ in 0..EPOCHS / 2 {
            resumed.step();
        }
        assert_eq!(
            resumed.world_hash(),
            expected,
            "a resumed run left the uninterrupted one: {case}"
        );
    }

    fn alive_cells(world: &World) -> Vec<(u32, u32)> {
        let mut cells = Vec::new();
        for y in 0..world.height() {
            for x in 0..world.width() {
                if world.cell(x, y)[0] != 0 {
                    cells.push((x, y));
                }
            }
        }
        cells
    }

    #[test]
    fn a_random_soup_fills_with_bytes_and_a_zero_soup_does_not() {
        let random = World::new(&soup(8, 8), 1).unwrap();
        assert!(random.cells.iter().any(|b| *b != 0));

        let zero = World::new(
            &Params {
                init: Init::Zero,
                ..soup(8, 8)
            },
            1,
        )
        .unwrap();
        assert!(zero.cells.iter().all(|b| *b == 0));
    }

    #[test]
    fn invalid_params_are_refused() {
        assert!(World::new(&soup(2, 8), 1).is_err());
    }

    #[test]
    fn a_zero_world_without_mutation_never_changes() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 5).unwrap();
        let before = world.world_hash();
        for _ in 0..100 {
            world.step();
        }
        assert_eq!(world.epoch(), 100);
        assert_eq!(world.world_hash(), before);
    }

    #[test]
    fn a_random_soup_changes_within_an_epoch() {
        let mut world = World::new(&soup(16, 16), 5).unwrap();
        let before = world.world_hash();
        world.step();
        assert_ne!(world.world_hash(), before);
    }

    #[test]
    fn soup_runs_are_determined_by_params_and_seed() {
        let params = soup(32, 32);
        let mut a = World::new(&params, 42).unwrap();
        let mut b = World::new(&params, 42).unwrap();
        let mut other = World::new(&params, 43).unwrap();
        for _ in 0..3 {
            a.step();
            b.step();
            other.step();
        }
        assert_eq!(a.world_hash(), b.world_hash());
        assert_ne!(a.world_hash(), other.world_hash());
    }

    /// Determinism is a property of the whole parameter space, not of one configuration:
    /// the interaction order, the mutation draws and the snapshot round-trip all have to
    /// hold whatever the neighbourhood, the tape length and the mutation rate are.
    #[test]
    fn determinism_holds_across_the_parameter_matrix() {
        for radius in [0, 1, 2] {
            for tape_len in [16, 64] {
                for mutation_rate in [0.0, 1.0 / 256.0] {
                    for seed in [1, 2, 3] {
                        assert_deterministic(
                            &Params {
                                radius,
                                tape_len,
                                mutation_rate,
                                ..soup(16, 16)
                            },
                            seed,
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn pinned_soup_determinism() {
        let mut world = World::new(&soup(32, 32), 42).unwrap();
        for _ in 0..50 {
            world.step();
        }
        assert_eq!(world.world_hash(), PINNED_SOUP_HASH);
    }

    #[test]
    fn pinned_determinism_of_a_soup_without_the_copy_to_head0_op() {
        let params = Params {
            ops: "<>{}+-.[]".to_string(),
            ..soup(32, 32)
        };
        let mut world = World::new(&params, 42).unwrap();
        for _ in 0..50 {
            world.step();
        }
        assert_eq!(world.world_hash(), PINNED_ABLATED_SOUP_HASH);
        assert_ne!(world.world_hash(), PINNED_SOUP_HASH);
    }

    #[test]
    fn pinned_life_determinism() {
        let mut world = World::new(
            &Params {
                init: Init::Random,
                ..life(32, 32)
            },
            42,
        )
        .unwrap();
        for _ in 0..50 {
            world.step();
        }
        assert_eq!(world.world_hash(), PINNED_LIFE_HASH);
    }

    #[test]
    fn a_snapshot_restores_the_world_and_the_run_continues_identically() {
        let params = soup(8, 8);
        let mut world = World::new(&params, 9).unwrap();
        for _ in 0..4 {
            world.step();
        }
        let bytes = world.snapshot();
        let mut restored = World::from_snapshot(&params, 9, &bytes).unwrap();
        assert_eq!(restored.epoch(), world.epoch());
        assert_eq!(restored.world_hash(), world.world_hash());

        world.step();
        restored.step();
        assert_eq!(restored.world_hash(), world.world_hash());
    }

    #[test]
    fn a_blinker_oscillates_with_period_two() {
        let params = life(8, 8);
        let mut world = World::new(&params, 0).unwrap();
        for x in 2..5 {
            world.set_cell(x, 3, &[1]);
        }
        let horizontal = alive_cells(&world);

        world.step();
        assert_eq!(alive_cells(&world), vec![(3, 2), (3, 3), (3, 4)]);
        world.step();
        assert_eq!(alive_cells(&world), horizontal);
    }

    #[test]
    fn a_glider_moves_one_cell_diagonally_every_four_generations() {
        let params = life(16, 16);
        let mut world = World::new(&params, 0).unwrap();
        let glider = [(2, 1), (3, 2), (1, 3), (2, 3), (3, 3)];
        for (x, y) in glider {
            world.set_cell(x, y, &[1]);
        }

        for _ in 0..4 {
            world.step();
        }
        let expected: Vec<(u32, u32)> = {
            let mut moved: Vec<(u32, u32)> = glider.iter().map(|(x, y)| (x + 1, y + 1)).collect();
            moved.sort_by_key(|(x, y)| (*y, *x));
            moved
        };
        assert_eq!(alive_cells(&world), expected);
    }

    #[test]
    fn a_blinker_oscillates_across_the_wrap_of_a_non_square_torus() {
        let params = life(5, 9);
        let mut world = World::new(&params, 0).unwrap();
        let vertical = [(0, 8), (0, 0), (0, 1)];
        for (x, y) in vertical {
            world.set_cell(x, y, &[1]);
        }

        world.step();
        assert_eq!(alive_cells(&world), vec![(0, 0), (1, 0), (4, 0)]);
        world.step();
        assert_eq!(alive_cells(&world), vec![(0, 0), (0, 1), (0, 8)]);
    }

    #[test]
    fn a_life_world_restored_from_a_snapshot_steps_identically() {
        let params = Params {
            init: Init::Random,
            ..life(16, 16)
        };
        let mut world = World::new(&params, 7).unwrap();
        world.step();

        let mut restored = World::from_snapshot(&params, 7, &world.snapshot()).unwrap();
        assert_eq!(restored.world_hash(), world.world_hash());
        world.step();
        restored.step();
        assert_eq!(restored.world_hash(), world.world_hash());
    }

    #[test]
    fn metrics_read_a_random_soup_as_noise() {
        let mut world = World::new(&soup(16, 16), 3).unwrap();
        let measured = world.metrics();
        assert!(measured.compress_ratio > 0.9, "{measured:?}");
        assert!(measured.entropy_bits > 7.9, "{measured:?}");
        assert!(
            (measured.op_density - 10.0 / 256.0).abs() < 0.02,
            "{measured:?}"
        );
        assert_eq!(measured.distinct_tapes, 256);
        assert_eq!(
            measured.alphabet_size, 256,
            "a random soup holds every byte value"
        );
        assert_eq!(measured.replicator_count, 0);
        assert_eq!(measured.copy_rate, 0.0, "nothing has interacted yet");
        assert!((measured.top_share - 1.0 / 256.0).abs() < 1e-9);
    }

    #[test]
    fn metrics_count_the_cells_holding_a_replicator() {
        let params = Params {
            tape_len: 256,
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(4, 4)
        };
        let mut world = World::new(&params, 3).unwrap();
        let tape = replicator::handwritten_replicator();
        for x in 0..3 {
            world.set_cell(x, 0, &tape);
        }
        let measured = world.metrics();
        assert_eq!(measured.replicator_count, 3);
        assert!(
            (measured.top_share - 13.0 / 16.0).abs() < 1e-9,
            "{measured:?}"
        );
    }

    #[test]
    fn metrics_read_no_replicator_when_the_run_ablates_the_op_it_copies_with() {
        let params = Params {
            tape_len: 256,
            init: Init::Zero,
            mutation_rate: 0.0,
            ops: "<>{}+-,[]".to_string(),
            ..soup(4, 4)
        };
        let mut world = World::new(&params, 3).unwrap();
        let tape = replicator::handwritten_replicator();
        for x in 0..3 {
            world.set_cell(x, 0, &tape);
        }
        assert_eq!(world.metrics().replicator_count, 0);
    }

    #[test]
    fn copy_rate_catches_a_replicator_copying_in_situ() {
        let params = Params {
            tape_len: 256,
            mutation_rate: 0.0,
            sample_every: 1,
            ..soup(4, 4)
        };
        let mut world = World::new(&params, 3).unwrap();
        assert_eq!(world.metrics().copy_rate, 0.0, "no interaction has run yet");

        let tape = replicator::handwritten_replicator();
        for x in 0..4 {
            world.set_cell(x, 0, &tape);
        }
        world.step();
        let seeded = world.metrics().copy_rate;
        assert!(seeded > 0.0, "{seeded}");

        let mut control = World::new(&params, 3).unwrap();
        control.step();
        assert!(control.metrics().copy_rate < seeded, "{seeded}");
    }

    #[test]
    fn copy_rate_is_counted_only_on_the_epochs_a_sample_reads() {
        let params = Params {
            tape_len: 256,
            mutation_rate: 0.0,
            sample_every: 3,
            ..soup(4, 4)
        };
        let tape = replicator::handwritten_replicator();
        let mut world = World::new(&params, 3).unwrap();
        for x in 0..4 {
            world.set_cell(x, 0, &tape);
        }

        world.step();
        assert_eq!(world.metrics().copy_rate, 0.0, "epoch 1 is not sampled");
        world.step();
        world.step();
        assert!(world.metrics().copy_rate > 0.0, "epoch 3 is");
    }

    #[test]
    fn a_frozen_monoculture_reports_no_copies() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            sample_every: 1,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 3).unwrap();
        let before = world.world_hash();
        world.step();

        assert_eq!(world.world_hash(), before, "nothing moved");
        assert_eq!(
            world.metrics().copy_rate,
            0.0,
            "identical halves are not a copy"
        );
    }

    #[test]
    fn life_reports_no_copies() {
        let mut world = World::new(
            &Params {
                init: Init::Random,
                sample_every: 1,
                ..life(8, 8)
            },
            2,
        )
        .unwrap();
        world.step();
        assert_eq!(world.metrics().copy_rate, 0.0);
    }

    #[test]
    fn a_uniform_soup_reads_as_ordered() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 3).unwrap();
        let measured = world.metrics();
        assert!(measured.compress_ratio < 0.1, "{measured:?}");
        assert_eq!(measured.distinct_tapes, 1);
        assert_eq!(measured.top_share, 1.0);
        assert_eq!(measured.entropy_bits, 0.0);
        assert_eq!(measured.alphabet_size, 1);
    }

    #[test]
    fn a_sample_taken_with_its_snapshot_reads_the_same_metrics() {
        let params = soup(16, 16);
        let mut world = World::new(&params, 5).unwrap();
        world.step();

        let (together, raw) = world.clone().metrics_with_snapshot();
        assert_eq!(together, world.metrics());
        assert_eq!(raw, world.snapshot());
        assert_eq!(world.transition_epoch(), None);
    }

    /// The census is a pure function of the world, so rescoring a stored snapshot must
    /// return the run's own reading — the one exception is `copy_rate`, which counts the
    /// interactions of the epoch just run and a restored world has run none.
    #[test]
    fn a_world_restored_from_a_snapshot_rescores_the_census_the_run_reported() {
        let params = Params {
            tape_len: replicator::handwritten_replicator().len() as u32,
            ..soup(16, 16)
        };
        let seed = 7;
        let mut world = World::new(&params, seed).unwrap();
        let tape = replicator::handwritten_replicator();
        for y in 0..params.height / 2 {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }
        for _ in 0..params.sample_every {
            world.step();
        }

        let (live, raw) = world.metrics_with_snapshot();
        let mut restored = World::from_snapshot(&params, seed, &raw).unwrap();
        let rescored = restored.metrics();

        assert!(live.replicator_count > 0, "the soup must hold replicators");
        assert!(
            live.distinct_tapes > 1 && live.top_share < 1.0,
            "a uniform soup would make the shape readings agree trivially: {live:?}"
        );
        assert_eq!(restored.epoch(), world.epoch());
        assert_eq!(rescored.replicator_count, live.replicator_count);
        assert_eq!(rescored.distinct_tapes, live.distinct_tapes);
        assert_eq!(rescored.top_share, live.top_share);
        assert_eq!(rescored.compress_ratio, live.compress_ratio);
        assert_eq!(rescored.entropy_bits, live.entropy_bits);
        assert_eq!(rescored.op_density, live.op_density);
        assert_eq!(rescored.alphabet_size, live.alphabet_size);
        assert!(live.copy_rate > 0.0, "the epoch just run must have copied");
        assert_eq!(rescored.copy_rate, 0.0);
    }

    #[test]
    fn the_transition_epoch_is_the_start_of_a_sustained_drop() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(16, 16)
        };
        let mut world = quiet_diverse_soup(&params);
        assert_eq!(world.transition_epoch(), None);
        for _ in 0..4 {
            world.metrics();
            world.step();
        }
        assert_eq!(world.transition_epoch(), Some(0));
    }

    #[test]
    fn a_snapshot_carries_the_transition_epoch_across_a_resume() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(16, 16)
        };
        let mut world = quiet_diverse_soup(&params);
        for _ in 0..3 {
            world.metrics();
            world.step();
        }
        assert_eq!(world.transition_epoch(), None, "the drop has not held yet");

        let mut restored = World::from_snapshot(&params, 3, &world.snapshot()).unwrap();
        restored.metrics();
        assert_eq!(restored.transition_epoch(), Some(0));
    }

    /// A resumed run samples its snapshot's own epoch again, so the restored tracker has
    /// to remember which epoch it last saw or the drop counts as held one sample early.
    #[test]
    fn a_resume_does_not_count_the_re_sampled_snapshot_epoch_twice() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(16, 16)
        };
        let mut world = quiet_diverse_soup(&params);
        for _ in 0..2 {
            world.metrics();
            world.step();
        }
        world.metrics();

        let mut restored = World::from_snapshot(&params, 3, &world.snapshot()).unwrap();
        restored.metrics();
        assert_eq!(
            restored.transition_epoch(),
            None,
            "epoch 2 had already been observed"
        );

        restored.step();
        restored.metrics();
        assert_eq!(restored.transition_epoch(), Some(0));
    }

    /// Production run 183's shape: with no mutation only `+`/`-` can mint a byte value,
    /// so a well-mixed soup can drift down to two instruction bytes — compressible, all
    /// ops, replicating nothing. The guard keeps that out of the transition count.
    #[test]
    fn a_two_symbol_soup_reads_a_tiny_alphabet_and_never_transitions() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            sample_every: 1,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 3).unwrap();
        let mut rng = rng::seeded(11, 0, 0);
        let tape: Vec<u8> = (0..params.stride())
            .map(|_| {
                if rng::chance(&mut rng, 0.67) {
                    b'{'
                } else {
                    b'.'
                }
            })
            .collect();
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }

        for _ in 0..8 {
            let measured = world.metrics();
            assert_eq!(measured.alphabet_size, 2, "{measured:?}");
            assert_eq!(measured.op_density, 1.0, "both letters are instructions");
            assert!(measured.compress_ratio < 0.6, "{measured:?}");
            world.step();
        }
        assert_eq!(world.transition_epoch(), None);
    }

    #[test]
    fn a_soup_seeded_with_replicators_still_transitions() {
        let params = Params {
            tape_len: replicator::handwritten_replicator().len() as u32,
            mutation_rate: 0.0,
            sample_every: 1,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 7).unwrap();
        let tape = replicator::handwritten_replicator();
        for y in 0..params.height / 2 {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }

        for _ in 0..8 {
            world.metrics();
            world.step();
        }
        let measured = world.metrics();
        assert!(measured.alphabet_size >= 16, "{measured:?}");
        assert!(measured.op_density <= 0.9, "{measured:?}");
        assert!(world.transition_epoch().is_some(), "{measured:?}");
    }

    #[test]
    fn a_life_world_reads_an_alphabet_of_two() {
        let params = Params {
            init: Init::Random,
            ..life(16, 16)
        };
        let mut world = World::new(&params, 4).unwrap();

        assert_eq!(world.metrics().alphabet_size, 2, "life cells are 0 or 1");
    }

    #[test]
    fn rendering_gives_one_rgba_pixel_per_cell() {
        let mut world = World::new(&life(4, 4), 0).unwrap();
        world.set_cell(1, 0, &[1]);
        let mut buf = vec![0u8; 4 * 4 * 4];
        world.render_rgba(&mut buf);
        assert_eq!(&buf[0..4], &[0, 0, 0, 255]);
        assert_eq!(&buf[4..8], &[255, 255, 255, 255]);

        let soup_world = World::new(&soup(4, 4), 1).unwrap();
        let mut buf = vec![0u8; 4 * 4 * 4];
        soup_world.render_rgba(&mut buf);
        assert!(buf.as_chunks::<4>().0.iter().all(|p| p[3] == 255));
    }

    #[test]
    fn a_well_mixed_world_reaches_beyond_the_neighbourhood() {
        let params = Params {
            radius: 0,
            ..soup(8, 8)
        };
        let world = World::new(&params, 1).unwrap();
        let mut rng = rng::seeded(1, STREAM_STEP, 0);
        let partners: Vec<usize> = (0..200).map(|_| world.pick_partner(0, &mut rng)).collect();
        assert!(partners.iter().all(|p| *p != 0));
        assert!(partners.iter().any(|p| *p > 9), "reaches the far side");
    }

    #[test]
    fn a_radius_one_partner_is_always_a_moore_neighbour() {
        let world = World::new(&soup(8, 8), 1).unwrap();
        let mut rng = rng::seeded(1, STREAM_STEP, 0);
        let centre = 3 * 8 + 3;
        for _ in 0..200 {
            let partner = world.pick_partner(centre, &mut rng);
            let dx = (partner % 8) as isize - 3;
            let dy = (partner / 8) as isize - 3;
            assert!(
                dx.abs() <= 1 && dy.abs() <= 1 && (dx, dy) != (0, 0),
                "{dx},{dy}"
            );
        }
    }
}
