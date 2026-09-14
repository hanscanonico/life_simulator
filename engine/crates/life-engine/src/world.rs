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
    /// One lineage id per cell, unique at init and inherited by descent in `step_soup`.
    /// Empty on the life substrate. A tag is read and written beside the tapes and never
    /// from the RNG stream, so a run's bytes are what they were before lineages existed.
    lineages: Vec<u64>,
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
            lineages: fresh_lineages(params),
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

    /// The lineage id of one cell: the ancestor its tape descends from by copying
    /// (`docs/DESIGN.md` §1.2). 0 on the life substrate, which carries no lineages.
    pub fn lineage(&self, x: u32, y: u32) -> u64 {
        self.lineages.get(self.index(x, y)).copied().unwrap_or(0)
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
            snapshot::encode_compressed(&self.snapshot_header(), &payload, &self.lineages),
        )
    }

    pub fn transition_epoch(&self) -> Option<u64> {
        self.transition.epoch()
    }

    pub fn world_hash(&self) -> u64 {
        fnv1a64(&self.cells)
    }

    pub fn snapshot(&self) -> Vec<u8> {
        snapshot::encode(&self.snapshot_header(), &self.cells, &self.lineages)
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

    /// The snapshot format (v3) carries the lineage tags beside the tapes, so a resumed
    /// run continues its lineage census where the snapshot left it. A version 1 or 2 blob
    /// held tapes only: its lineages are minted fresh, one id per cell, and only the two
    /// lineage observables read a world younger than it is.
    pub fn from_snapshot(params: &Params, seed: u64, bytes: &[u8]) -> Result<Self, SnapshotError> {
        let restored = snapshot::decode(params, bytes)?;
        Ok(Self {
            params: params.clone(),
            seed,
            epoch: restored.header.epoch,
            cells: restored.cells,
            scratch: life_scratch(params),
            transition: TransitionTracker::from_state(restored.header.transition),
            copy_rate: 0.0,
            lineages: restored.lineages.unwrap_or_else(|| fresh_lineages(params)),
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
    /// of those interactions. The pre-execution pair is kept every epoch — the lineage
    /// rule reads it — and counting copies adds at most three comparisons per interaction,
    /// so it stays off on every other epoch.
    fn step_soup(&mut self, rng: &mut Rng) {
        let stride = self.params.stride();
        let max_steps = self.params.max_steps;
        let ops = self.params.op_set();
        let counting = self.counts_copies();
        let mut energy = EpochEnergy::recharged(&self.params, self.params.cell_count());
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
            before.copy_from_slice(&pair);
            let budget = energy.budget(a, b, max_steps);
            let outcome = bff::run_with(&mut pair, budget, ops);
            energy.spend(a, b, outcome.steps);
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
            self.inherit_lineages(a, b, &pair, &before, stride);
        }
        if counting {
            self.copy_rate = if interactions == 0 {
                0.0
            } else {
                copies as f64 / interactions as f64
            };
        }
    }

    /// Descent, read off the one interaction that just ran: a cell takes its partner's
    /// lineage id when the tape it ends with is closer to the tape its partner arrived
    /// with than to the tape it arrived with itself, and keeps its own on a tie. Both
    /// cells are judged against the pair as it arrived, so an exchange swaps the two tags
    /// rather than collapsing them onto one.
    fn inherit_lineages(&mut self, a: usize, b: usize, pair: &[u8], before: &[u8], stride: usize) {
        let (was_a, was_b) = (self.lineages[a], self.lineages[b]);
        if inherits_partner(&pair[..stride], &before[..stride], &before[stride..]) {
            self.lineages[a] = was_b;
        }
        if inherits_partner(&pair[stride..], &before[stride..], &before[..stride]) {
            self.lineages[b] = was_a;
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

    /// A structure changes the probability each byte faces and never where the RNG stream
    /// stands: the bytes are visited in the one order either world visits them, and each
    /// is offered exactly one draw.
    fn mutate(&mut self, rng: &mut Rng) {
        if self.params.mutation_rate <= 0.0 {
            return;
        }
        let substrate = self.params.substrate;
        let width = self.params.width;
        let stride = self.params.stride();
        for (cell, state) in self.cells.chunks_mut(stride).enumerate() {
            let rate = self
                .params
                .mutation_rate_at(cell as u32 % width, cell as u32 / width);
            for byte in state {
                if rng::chance(rng, rate) {
                    *byte = draw_cell_byte(rng, substrate);
                }
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
        let (distinct_lineages, top_lineage_share) = metrics::lineage_census(&self.lineages);
        let census = self.replicator_census(&ranked);

        Metrics {
            compress_ratio,
            distinct_tapes: ranked.len() as u64,
            top_share,
            op_density: histogram.op_density(),
            replicator_count: census.count,
            entropy_bits: histogram.entropy_bits(),
            alphabet_size: histogram.alphabet_size(),
            copy_rate: self.copy_rate,
            distinct_lineages,
            top_lineage_share,
            lineage_variation: metrics::lineage_variation(&self.cells, stride, &self.lineages),
            copy_cost: census.copy_cost,
            dominant_compressed_len: census.complexity.map(|read| read.compressed_len),
            dominant_instruction_count: census.complexity.map(|read| read.instruction_count),
        }
    }

    /// Cells holding one of the `top_k` most common tapes that passes the replicator test,
    /// and what the dominant one — the first tape to pass, `ranked` being in population
    /// order — costs and carries. Life cells are single bits and have no replicator
    /// reading.
    fn replicator_census(&self, ranked: &[(&[u8], u64)]) -> ReplicatorCensus {
        if self.params.substrate != Substrate::Soup {
            return ReplicatorCensus::default();
        }
        let mut rng = rng::seeded(self.seed, STREAM_REPLICATOR, self.epoch);
        let ops = self.params.op_set();
        let mut census = ReplicatorCensus::default();
        for (tape, cells) in ranked.iter().take(self.params.top_k as usize) {
            let read = replicator::assay(tape, self.params.max_steps, ops, &mut rng);
            if read.replicates() {
                census.count += cells;
                if census.complexity.is_none() {
                    census.complexity = Some(metrics::Complexity::of(tape, ops));
                }
                census.copy_cost = census.copy_cost.or(read.copy_cost);
            }
        }
        census
    }
}

/// What one sample's run of the replicator test read: how many cells hold a tape that
/// passed, and the dominant passing tape's own observables.
#[derive(Default)]
struct ReplicatorCensus {
    count: u64,
    copy_cost: Option<u32>,
    complexity: Option<metrics::Complexity>,
}

/// What the epoch's cells have left to spend on instructions (`energy_per_epoch`,
/// DESIGN §1.3 sweep 6). The cost is opt-in, and `Free` is what off means: no per-cell
/// budget exists, nothing is allocated and an interaction is capped by `max_steps` alone.
enum EpochEnergy {
    Free,
    Budgeted(Vec<u32>),
}

impl EpochEnergy {
    fn recharged(params: &Params, cell_count: usize) -> Self {
        match params.energy_per_epoch {
            0 => Self::Free,
            budget => Self::Budgeted(vec![budget; cell_count]),
        }
    }

    /// How many instructions one interaction may execute: what the poorer of the two cells
    /// has left of its epoch's energy, never more than `max_steps`. Both cells execute the
    /// one concatenated program, so neither can pay past its own budget and the interaction
    /// halts where the poorer one runs dry.
    fn budget(&self, a: usize, b: usize, max_steps: u32) -> u32 {
        match self {
            Self::Free => max_steps,
            Self::Budgeted(left) => max_steps.min(left[a]).min(left[b]),
        }
    }

    /// Debits both cells of an interaction with the instructions it executed.
    fn spend(&mut self, a: usize, b: usize, steps: u32) {
        if let Self::Budgeted(left) = self {
            left[a] -= steps;
            left[b] -= steps;
        }
    }
}

/// Why an interaction stopped, as the world reads it. The interpreter only ever knows the
/// cap it was handed, so a halt at a cap the epoch's energy imposed — rather than
/// `max_steps` — reads as `EnergySpent` here: a soup whose interactions are cut short
/// because its cells are out of energy is a different reading from one whose programs
/// outrun the step budget. No observable of §1.2 records a halt, so the epoch loop does not
/// call this: it is the reading a caller that wants the two apart asks the world for.
pub fn halt_reason(outcome: &bff::Outcome, budget: u32, max_steps: u32) -> bff::Halt {
    if outcome.halt == bff::Halt::StepLimit && budget < max_steps {
        return bff::Halt::EnergySpent;
    }
    outcome.halt
}

/// Whether a tape resembles its partner's arriving tape more closely than its own, by
/// Hamming distance over the tape's bytes — the plainest distance on a fixed-length tape,
/// and the same byte-by-byte reading `copy_rate` makes of an exact copy. A tie keeps the
/// cell's own lineage, so a tape that did not move keeps its tag.
fn inherits_partner(result: &[u8], own: &[u8], partner: &[u8]) -> bool {
    metrics::hamming_distance(result, partner) < metrics::hamming_distance(result, own)
}

/// One id per cell, unique in the world: the cell's own index, so a lineage census at
/// epoch 0 reads one cell per lineage without drawing anything.
fn fresh_lineages(params: &Params) -> Vec<u64> {
    (0..params.lineage_count() as u64).collect()
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
    use crate::metrics::TransitionState;
    use crate::params::Structure;

    /// Pinned so a change in the rules, the RNG or the visiting order cannot pass unseen:
    /// `Params::default()` at 32×32, seed 42, after 50 epochs.
    const PINNED_SOUP_HASH: u64 = 0xd25f_8c16_3d9e_2dd9;
    const PINNED_LIFE_HASH: u64 = 0x200a_f822_08b5_96b9;
    /// The same run with `,` ablated (DESIGN §1.3, sweep 5).
    const PINNED_ABLATED_SOUP_HASH: u64 = 0xb115_dbaa_f8d8_9bec;
    /// The §1.2 observables of that same run, as they read before lineage tags.
    const PINNED_OBSERVABLES: &str = "compress_ratio=0.9942169189453125 distinct_tapes=1024 \
         top_share=0.0009765625 op_density=0.04241943359375 replicator_count=0 \
         entropy_bits=7.995914331881839 alphabet_size=256 copy_rate=0.0";
    /// And of a 16×16 soup half seeded with the handwritten replicator, seed 7, epoch 10 —
    /// a world where every observable reads something, `copy_rate` included.
    const PINNED_SEEDED_OBSERVABLES: &str = "compress_ratio=0.01153564453125 distinct_tapes=57 \
         top_share=0.49609375 op_density=0.058837890625 replicator_count=196 \
         entropy_bits=0.5501352213732266 alphabet_size=61 copy_rate=0.51171875";
    /// The lineage observables of those same two worlds, as they read when #158 added
    /// them — a within-lineage reading must not move a lineage.
    const PINNED_LINEAGES: &str = "distinct_lineages=1022 top_lineage_share=0.001953125";
    const PINNED_SEEDED_LINEAGES: &str = "distinct_lineages=51 top_lineage_share=0.09375";

    fn observable_digest(measured: &Metrics) -> String {
        format!(
            "compress_ratio={:?} distinct_tapes={} top_share={:?} op_density={:?} \
             replicator_count={} entropy_bits={:?} alphabet_size={} copy_rate={:?}",
            measured.compress_ratio,
            measured.distinct_tapes,
            measured.top_share,
            measured.op_density,
            measured.replicator_count,
            measured.entropy_bits,
            measured.alphabet_size,
            measured.copy_rate,
        )
    }

    /// The two lineage observables of #158, read apart from the digest above: that one is
    /// pinned to readings taken before lineages existed and cannot carry them.
    fn lineage_digest(measured: &Metrics) -> String {
        format!(
            "distinct_lineages={} top_lineage_share={:?}",
            measured.distinct_lineages, measured.top_lineage_share,
        )
    }

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

    /// A soup of nothing but `+`: head0 never moves, so every increment an interaction
    /// executes lands on the first byte of the cell that opened it, and that byte counts
    /// the instructions the cell has paid for. One interaction over two 8-byte tapes costs
    /// 16 instructions, well inside `max_steps`.
    fn adding_params() -> Params {
        Params {
            tape_len: 8,
            mutation_rate: 0.0,
            ..soup(8, 8)
        }
    }

    /// One interaction over two 8-byte tapes executes 16 instructions. All but at most
    /// one are increments: the partner's first byte has stopped being a `+` if it opened
    /// an interaction earlier in the epoch, and a byte that is no longer an op is a no-op
    /// that still costs its step.
    const ADDING_INTERACTION_STEPS: u32 = 16;

    fn adding_soup(params: &Params) -> World {
        let mut world = World::new(params, 11).unwrap();
        let tape = vec![b'+'; params.stride()];
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }
        world
    }

    fn increments(world: &World) -> Vec<u32> {
        let mut counted = Vec::with_capacity(world.params.cell_count());
        for y in 0..world.height() {
            for x in 0..world.width() {
                counted.push(u32::from(world.cell(x, y)[0].wrapping_sub(b'+')));
            }
        }
        counted
    }

    fn stepped(params: &Params, seed: u64, epochs: u64) -> World {
        let mut world = World::new(params, seed).unwrap();
        for _ in 0..epochs {
            world.step();
        }
        world
    }

    fn colony_params() -> Params {
        Params {
            tape_len: replicator::handwritten_replicator().len() as u32,
            mutation_rate: 0.0,
            ..soup(8, 8)
        }
    }

    /// A soup with one row of the handwritten replicator in it: a world whose lineage
    /// census moves, epoch by epoch, as the colony copies itself over its neighbours.
    fn colony(params: &Params, seed: u64) -> World {
        let mut world = World::new(params, seed).unwrap();
        let tape = replicator::handwritten_replicator();
        for x in 0..params.width {
            world.set_cell(x, 0, &tape);
        }
        world
    }

    fn lineage_series(world: &mut World, epochs: usize) -> Vec<(u64, f64)> {
        (0..epochs)
            .map(|_| {
                world.step();
                let measured = world.metrics();
                (measured.distinct_lineages, measured.top_lineage_share)
            })
            .collect()
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

    /// Determinism has to hold under the instruction cost as well: the energy is spent in
    /// the order the shuffle already fixed, and it is derived from the epoch alone, so a
    /// run resumed from a snapshot recharges exactly as the uninterrupted one did.
    #[test]
    fn determinism_holds_under_an_instruction_cost() {
        for energy_per_epoch in [64, 4096] {
            for seed in [1, 2, 3] {
                assert_deterministic(
                    &Params {
                        energy_per_epoch,
                        ..soup(16, 16)
                    },
                    seed,
                );
            }
        }
    }

    /// And under a structured world: the rate a byte faces comes from its position alone,
    /// so a run resumed from a snapshot mutates exactly as the uninterrupted one did.
    #[test]
    fn determinism_holds_under_environmental_structure() {
        for structure in [Structure::Gradient, Structure::Patchwork] {
            for seed in [1, 2, 3] {
                assert_deterministic(
                    &Params {
                        structure,
                        structure_amplitude: 0.75,
                        mutation_rate: 1.0 / 256.0,
                        ..soup(16, 16)
                    },
                    seed,
                );
            }
        }
    }

    /// Every observable of §1.2 as it read before lineage tags existed, captured at
    /// `Params::default()` 32×32, seed 42, epoch 50 on the commit before them. A run is
    /// determined by `(params, seed)`, so anything that moved a tape byte or drew from the
    /// RNG stream would move these digits too.
    #[test]
    fn the_observables_of_a_fixed_seed_read_what_they_read_before_lineage_tags() {
        let mut world = World::new(&soup(32, 32), 42).unwrap();
        for _ in 0..50 {
            world.step();
        }
        let measured = world.metrics();
        assert_eq!(observable_digest(&measured), PINNED_OBSERVABLES);
        assert_eq!(lineage_digest(&measured), PINNED_LINEAGES);
    }

    #[test]
    fn the_observables_of_a_seeded_soup_read_what_they_read_before_lineage_tags() {
        let params = Params {
            tape_len: replicator::handwritten_replicator().len() as u32,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 7).unwrap();
        let tape = replicator::handwritten_replicator();
        for y in 0..params.height / 2 {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }
        for _ in 0..params.sample_every {
            world.step();
        }
        let measured = world.metrics();
        assert_eq!(observable_digest(&measured), PINNED_SEEDED_OBSERVABLES);
        assert_eq!(lineage_digest(&measured), PINNED_SEEDED_LINEAGES);
    }

    /// A colony of the handwritten replicator is one lineage spreading: each cell it
    /// copies itself over ends holding the copier's arriving tape, which is as close to it
    /// as a tape can be, so the tag travels with the bytes.
    #[test]
    fn a_replicator_spreads_one_lineage_across_the_world() {
        let params = Params {
            tape_len: replicator::handwritten_replicator().len() as u32,
            mutation_rate: 0.0,
            ..soup(8, 8)
        };
        let mut world = World::new(&params, 5).unwrap();
        assert_eq!(
            world.metrics().distinct_lineages,
            64,
            "every cell starts its own lineage"
        );

        let tape = replicator::handwritten_replicator();
        for x in 0..params.width {
            world.set_cell(x, 0, &tape);
        }
        for _ in 0..40 {
            world.step();
        }
        let measured = world.metrics();

        assert!(
            measured.top_lineage_share > 0.5,
            "one lineage should hold the world: {measured:?}"
        );
        assert!(measured.distinct_lineages < 16, "{measured:?}");

        let mut control = World::new(&params, 5).unwrap();
        for _ in 0..40 {
            control.step();
        }
        let drifted = control.metrics();
        assert!(
            drifted.top_lineage_share < measured.top_lineage_share,
            "a soup with no replicator in it should stay polyphyletic: {drifted:?}"
        );
    }

    /// Descent is decided on the pair the interpreter just ran, which is before the epoch
    /// mutates: a byte flipped by mutation cannot move a tag.
    #[test]
    fn mutation_never_moves_a_lineage_id() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.5,
            ..soup(8, 8)
        };
        let mut world = World::new(&params, 2).unwrap();
        let before: Vec<u64> = (0..8).map(|x| world.lineage(x, 0)).collect();
        world.step();

        assert_ne!(world.world_hash(), 0, "mutation rewrote the tapes");
        let after: Vec<u64> = (0..8).map(|x| world.lineage(x, 0)).collect();
        assert_eq!(after, before);
    }

    /// A cell overwritten by its partner takes the partner's tag, so a tag only ever
    /// travels where the bytes it belongs to travelled: every copy of the seeded tape is
    /// tagged with one of the cells it was seeded into, never with the cell it landed on.
    #[test]
    fn a_copied_over_cell_takes_its_partners_lineage() {
        let params = Params {
            tape_len: replicator::handwritten_replicator().len() as u32,
            mutation_rate: 0.0,
            ..soup(4, 4)
        };
        let mut world = World::new(&params, 1).unwrap();
        let tape = replicator::handwritten_replicator();
        for x in 0..params.width {
            world.set_cell(x, 0, &tape);
        }
        let seeded: Vec<u64> = (0..params.width).map(|x| world.lineage(x, 0)).collect();

        let mut copies: Vec<(u32, u32)> = Vec::new();
        for _ in 0..20 {
            world.step();
            copies = (0..params.width)
                .flat_map(|x| (1..params.height).map(move |y| (x, y)))
                .filter(|(x, y)| world.cell(*x, *y) == tape)
                .collect();
            if !copies.is_empty() {
                break;
            }
        }
        assert!(!copies.is_empty(), "the replicator must have spread");
        for (x, y) in copies {
            let tag = world.lineage(x, y);
            assert!(seeded.contains(&tag), "cell {x},{y} kept its own tag {tag}");
        }
    }

    #[test]
    fn a_tape_inherits_only_when_it_ends_strictly_closer_to_its_partner() {
        assert!(
            inherits_partner(b"wxyz", b"abcd", b"wxyz"),
            "an exact copy of the partner's arriving tape inherits"
        );
        assert!(
            !inherits_partner(b"abcd", b"abcd", b"wxyz"),
            "a tape that did not move keeps its own tag"
        );
        assert!(
            !inherits_partner(b"abcz", b"abcd", b"wxyz"),
            "one byte from its own arrival, three from the partner's: keeps its own"
        );
        assert!(
            !inherits_partner(b"abyz", b"abcd", b"wxyz"),
            "two bytes from each arrival is a tie, and a tie keeps its own"
        );
    }

    /// Both halves are judged against the pair as it arrived, so a pair that swapped tapes
    /// swaps its two tags rather than collapsing both onto one.
    #[test]
    fn an_exchange_of_tapes_swaps_the_two_lineage_tags() {
        let params = Params {
            tape_len: 8,
            ..soup(4, 4)
        };
        let mut world = World::new(&params, 1).unwrap();
        let stride = params.stride();
        let before = *b"abcdefghstuvwxyz";
        let exchanged = *b"stuvwxyzabcdefgh";
        let (was_a, was_b) = (world.lineage(0, 0), world.lineage(1, 0));
        assert_ne!(was_a, was_b);

        world.inherit_lineages(0, 1, &exchanged, &before, stride);

        assert_eq!((world.lineage(0, 0), world.lineage(1, 0)), (was_b, was_a));
    }

    /// A colony of clones varies by nothing, and mutation is what makes it vary: the same
    /// world seeded with one tape everywhere reads 0 without mutation and more the harder
    /// mutation pushes it apart.
    #[test]
    fn a_clonal_colony_varies_by_nothing_and_mutation_makes_it_drift() {
        assert_eq!(clonal_variation(0.0), 0.0);

        let drifting = clonal_variation(0.002);
        let drifting_harder = clonal_variation(0.02);
        assert!(
            drifting > 0.0,
            "mutation must split the lineage: {drifting}"
        );
        assert!(
            drifting_harder > drifting,
            "more mutation, more variation: {drifting_harder} vs {drifting}"
        );
    }

    /// A soup of one tape everywhere, so every lineage that holds more than a cell holds
    /// clones of it until mutation says otherwise, read after 20 epochs.
    fn clonal_variation(mutation_rate: f64) -> f64 {
        let params = Params {
            tape_len: replicator::handwritten_replicator().len() as u32,
            mutation_rate,
            ..soup(8, 8)
        };
        let mut world = World::new(&params, 11).unwrap();
        let tape = replicator::handwritten_replicator();
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }
        for _ in 0..20 {
            world.step();
        }
        world.metrics().lineage_variation
    }

    #[test]
    fn a_life_world_carries_no_lineages() {
        let mut world = World::new(&life(4, 4), 1).unwrap();
        let measured = world.metrics();
        assert_eq!(measured.distinct_lineages, 0);
        assert_eq!(measured.top_lineage_share, 0.0);
        assert_eq!(measured.lineage_variation, 0.0);
    }

    #[test]
    fn a_life_world_reads_nothing_of_a_dominant_replicator() {
        let mut world = World::new(&life(4, 4), 1).unwrap();
        let measured = world.metrics();
        assert_eq!(measured.replicator_count, 0);
        assert_eq!(measured.copy_cost, None);
        assert_eq!(measured.dominant_compressed_len, None);
        assert_eq!(measured.dominant_instruction_count, None);
    }

    #[test]
    fn an_interaction_halts_when_its_cells_have_spent_their_energy() {
        const BUDGET: u32 = 5;
        let mut free = adding_soup(&adding_params());
        free.step();
        let unpriced = increments(&free);
        assert!(
            unpriced
                .iter()
                .all(|paid| *paid >= ADDING_INTERACTION_STEPS - 1),
            "with the cost off every cell ran its program to the end: {unpriced:?}"
        );

        let mut costly = adding_soup(&Params {
            energy_per_epoch: BUDGET,
            ..adding_params()
        });
        costly.step();
        let paid = increments(&costly);
        assert!(
            paid.iter().all(|cell| *cell <= BUDGET),
            "a cell paid past its epoch's energy: {paid:?}"
        );
        assert!(
            paid.contains(&BUDGET),
            "no interaction reached the budget at all: {paid:?}"
        );
        assert!(
            paid.contains(&0),
            "the energy did not carry across the epoch's interactions: every cell still had \
             something to spend when its own turn came: {paid:?}"
        );
    }

    #[test]
    fn energy_recharges_at_the_start_of_the_next_epoch() {
        const BUDGET: u32 = 5;
        let mut world = adding_soup(&Params {
            energy_per_epoch: BUDGET,
            ..adding_params()
        });
        world.step();
        let first = increments(&world);
        world.step();
        let second = increments(&world);

        let exhausted: Vec<usize> = (0..first.len()).filter(|at| first[*at] == BUDGET).collect();
        assert!(!exhausted.is_empty());
        assert!(
            exhausted.iter().any(|at| second[*at] > first[*at]),
            "a cell that spent its whole budget never worked again: {first:?} then {second:?}"
        );
        assert!(
            (0..first.len()).all(|at| second[at] - first[at] <= BUDGET),
            "an epoch paid past its energy: {first:?} then {second:?}"
        );
    }

    #[test]
    fn a_halt_at_an_energy_cap_reads_apart_from_one_at_the_step_limit() {
        const MAX_STEPS: u32 = 64;
        let capped = bff::Outcome {
            halt: bff::Halt::StepLimit,
            steps: 8,
        };
        assert_eq!(
            halt_reason(&capped, 8, MAX_STEPS),
            bff::Halt::EnergySpent,
            "an interaction the epoch's energy cut short still read as a step-limit halt"
        );
        assert_eq!(
            halt_reason(&capped, MAX_STEPS, MAX_STEPS),
            bff::Halt::StepLimit
        );
    }

    /// Only a halt is renamed: a program that ended, or ran onto an unmatched bracket,
    /// stopped for its own reason however little energy was left to pay it.
    #[test]
    fn a_program_that_ended_on_its_own_keeps_its_halt_under_an_energy_cap() {
        for halt in [bff::Halt::EndOfTape, bff::Halt::UnmatchedBracket] {
            let outcome = bff::Outcome { halt, steps: 4 };
            assert_eq!(halt_reason(&outcome, 8, 64), halt);
        }
    }

    /// The cost is opt-in: naming it off must leave a run exactly where the parameter's
    /// absence left it, down to the bytes of the world and every observable of §1.2.
    #[test]
    fn the_instruction_cost_switched_off_moves_no_run() {
        let off = Params {
            energy_per_epoch: 0,
            ..soup(32, 32)
        };
        let mut world = World::new(&off, 42).unwrap();
        for _ in 0..50 {
            world.step();
        }
        assert_eq!(world.world_hash(), PINNED_SOUP_HASH);

        let measured = world.metrics();
        assert_eq!(observable_digest(&measured), PINNED_OBSERVABLES);
        assert_eq!(lineage_digest(&measured), PINNED_LINEAGES);
    }

    /// A budget no epoch can spend — every cell could pay for a full-length interaction
    /// many times over — has to read as the soup with the cost off: the accounting itself
    /// must not move a byte.
    #[test]
    fn an_unspendable_energy_budget_runs_the_soup_unchanged() {
        let params = Params {
            max_steps: 64,
            energy_per_epoch: 1_048_576,
            ..soup(16, 16)
        };
        let costly = stepped(&params, 42, 20);
        let free = stepped(
            &Params {
                energy_per_epoch: 0,
                ..params
            },
            42,
            20,
        );
        assert_eq!(costly.world_hash(), free.world_hash());
    }

    /// A world of zero tapes executes nothing — every byte is a no-op — so after one epoch
    /// the only bytes that moved are the ones mutation drew, and a cell's non-zero bytes
    /// count the mutations it was offered.
    fn mutated_bytes(world: &World, x: u32, y: u32) -> usize {
        world.cell(x, y).iter().filter(|byte| **byte != 0).count()
    }

    fn still_soup(structure: Structure) -> Params {
        Params {
            tape_len: 16,
            init: Init::Zero,
            mutation_rate: 0.5,
            structure,
            structure_amplitude: 1.0,
            ..soup(16, 16)
        }
    }

    /// The extremes of a gradient at full amplitude: the driest column runs at no rate at
    /// all and the wettest, half a world east, at twice the run's rate — every byte.
    #[test]
    fn a_gradient_mutates_by_column() {
        let mut world = World::new(&still_soup(Structure::Gradient), 5).unwrap();
        world.step();

        for y in 0..16 {
            assert_eq!(mutated_bytes(&world, 0, y), 0, "the driest column mutated");
            assert!(
                mutated_bytes(&world, 8, y) > 8,
                "the wettest column barely mutated"
            );
        }
    }

    #[test]
    fn a_patchwork_mutates_by_quadrant() {
        let mut world = World::new(&still_soup(Structure::Patchwork), 5).unwrap();
        world.step();

        for (x, y) in [(2, 2), (10, 10)] {
            assert_eq!(mutated_bytes(&world, x, y), 0, "a dry patch mutated");
        }
        for (x, y) in [(10, 2), (2, 10)] {
            assert!(
                mutated_bytes(&world, x, y) > 8,
                "a wet patch barely mutated"
            );
        }
    }

    /// The structure is opt-in: a uniform world must be the run the parameter's absence
    /// left, down to the bytes of the world and every observable of §1.2, whatever
    /// amplitude it carries unread.
    #[test]
    fn a_uniform_world_moves_no_run() {
        let uniform = Params {
            structure: Structure::Uniform,
            structure_amplitude: 1.0,
            ..soup(32, 32)
        };
        let mut world = World::new(&uniform, 42).unwrap();
        for _ in 0..50 {
            world.step();
        }
        assert_eq!(world.world_hash(), PINNED_SOUP_HASH);

        let measured = world.metrics();
        assert_eq!(observable_digest(&measured), PINNED_OBSERVABLES);
        assert_eq!(lineage_digest(&measured), PINNED_LINEAGES);
    }

    /// A structure of no amplitude is a uniform world by another name, and must run as one:
    /// the scaling itself must not move a byte.
    #[test]
    fn a_structure_of_no_amplitude_runs_the_soup_unchanged() {
        let params = Params {
            structure: Structure::Gradient,
            structure_amplitude: 0.0,
            ..soup(16, 16)
        };
        let structured = stepped(&params, 42, 20);
        let flat = stepped(
            &Params {
                structure: Structure::Uniform,
                ..params
            },
            42,
            20,
        );
        assert_eq!(structured.world_hash(), flat.world_hash());
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
    fn a_life_snapshot_restores_a_world_that_carries_no_lineages() {
        let params = Params {
            init: Init::Random,
            ..life(8, 8)
        };
        let mut world = World::new(&params, 4).unwrap();
        for _ in 0..3 {
            world.step();
        }

        let mut restored = World::from_snapshot(&params, 4, &world.snapshot()).unwrap();

        assert_eq!(restored.epoch(), world.epoch());
        assert_eq!(restored.world_hash(), world.world_hash());
        assert_eq!(restored.metrics().distinct_lineages, 0);
    }

    /// The lineage tags are world state now that a snapshot carries them, so a run cut in
    /// half and resumed has to read the same lineage series as the uninterrupted run —
    /// digit for digit, over a colony where the tags actually move.
    #[test]
    fn a_resumed_run_reads_the_lineage_series_of_an_uninterrupted_run() {
        const EPOCHS: usize = 20;
        let params = colony_params();
        let mut uninterrupted = colony(&params, 5);
        let mut interrupted = colony(&params, 5);

        let expected = lineage_series(&mut uninterrupted, EPOCHS);
        assert_eq!(
            lineage_series(&mut interrupted, EPOCHS / 2),
            expected[..EPOCHS / 2]
        );
        assert!(
            expected.last().unwrap().0 < expected.first().unwrap().0,
            "the colony must swallow lineages for the series to say anything: {expected:?}"
        );

        let mut resumed = World::from_snapshot(&params, 5, &interrupted.snapshot()).unwrap();
        assert_eq!(
            lineage_series(&mut resumed, EPOCHS / 2),
            expected[EPOCHS / 2..]
        );
    }

    /// A version 1 or 2 blob carries tapes and no tags: its lineages are minted fresh,
    /// one per cell, and the world it restores is otherwise the world that was stored.
    #[test]
    fn a_blob_from_before_lineage_tags_restores_with_one_lineage_per_cell() {
        let params = colony_params();
        let mut world = colony(&params, 5);
        for _ in 0..10 {
            world.step();
        }
        assert!(world.metrics().distinct_lineages < 64);

        let older = snapshot::legacy::v2_blob(
            &params,
            world.epoch(),
            TransitionState::default(),
            &world.cells,
        );
        let mut restored = World::from_snapshot(&params, 5, &older).unwrap();

        assert_eq!(restored.world_hash(), world.world_hash());
        assert_eq!(restored.epoch(), world.epoch());
        assert_eq!(restored.metrics().distinct_lineages, 64);
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
        assert_eq!(
            measured.copy_cost, None,
            "nothing replicates to cost anything"
        );
        assert_eq!(measured.dominant_compressed_len, None);
        assert_eq!(measured.dominant_instruction_count, None);
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
        assert_eq!(
            measured.copy_cost,
            Some(1_794),
            "the dominant replicator is the handwritten tape, at its known cost"
        );
        assert_eq!(
            (
                measured.dominant_compressed_len,
                measured.dominant_instruction_count
            ),
            (Some(36), Some(15)),
            "and at its known complexity"
        );
        assert!(
            (measured.top_share - 13.0 / 16.0).abs() < 1e-9,
            "{measured:?}"
        );
    }

    /// The hand-written copier with one filler byte pushed in front of its program: it
    /// copies exactly the same way one step later, which is a second replicator whose cost
    /// differs from the first by a known step.
    fn dearer_replicator() -> Vec<u8> {
        let mut tape = replicator::handwritten_replicator();
        let len = tape.len();
        tape.copy_within(1..len - 1, 2);
        tape[1] = b'a';
        tape
    }

    /// Which of several replicators the cost is read off is a population question, not an
    /// order-of-discovery one: with two of them in a world, the sample reports the cost of
    /// the tape more cells hold.
    #[test]
    fn the_copy_cost_is_read_off_the_most_populous_replicator() {
        let params = Params {
            tape_len: 256,
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(4, 4)
        };
        let cheap = replicator::handwritten_replicator();
        let dear = dearer_replicator();

        for (cheap_cells, expected) in [(3, 1_794), (1, 1_795)] {
            let mut world = World::new(&params, 3).unwrap();
            for x in 0..4 {
                world.set_cell(x, 0, if x < cheap_cells { &cheap } else { &dear });
            }
            let measured = world.metrics();
            assert_eq!(measured.replicator_count, 4, "{measured:?}");
            assert_eq!(measured.copy_cost, Some(expected), "{measured:?}");
        }
    }

    /// The hand-written copier with its filler replaced by non-zero junk, a third of it op
    /// bytes the interpreter never reaches: it copies itself exactly as the plain tape does
    /// and for the same 1 794 steps, so it is the same replicator at a different size.
    fn bulkier_replicator() -> Vec<u8> {
        let mut tape = replicator::handwritten_replicator();
        let mut state: u8 = 1;
        for (index, byte) in tape.iter_mut().enumerate().skip(16) {
            state = state.wrapping_mul(37).wrapping_add(11) | 1;
            *byte = if index % 3 == 0 { b'+' } else { state };
        }
        tape
    }

    /// Which of several replicators the complexity is read off is the same population
    /// question the cost is settled by, and the two readings must come off one tape: with
    /// two replicators of equal cost in a world, the sample reports the size of the tape
    /// more cells hold.
    #[test]
    fn the_complexity_is_read_off_the_most_populous_replicator() {
        let params = Params {
            tape_len: 256,
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(4, 4)
        };
        let plain = replicator::handwritten_replicator();
        let bulky = bulkier_replicator();

        for (plain_cells, expected) in [(3, (36, 15)), (1, (84, 95))] {
            let mut world = World::new(&params, 3).unwrap();
            for x in 0..4 {
                world.set_cell(x, 0, if x < plain_cells { &plain } else { &bulky });
            }
            let measured = world.metrics();
            assert_eq!(measured.replicator_count, 4, "{measured:?}");
            assert_eq!(
                measured.copy_cost,
                Some(1_794),
                "the two tapes cost the same, so only the size can tell them apart"
            );
            assert_eq!(
                (
                    measured.dominant_compressed_len,
                    measured.dominant_instruction_count
                ),
                (Some(expected.0), Some(expected.1)),
                "{measured:?}"
            );
        }
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
        assert!(
            live.distinct_lineages < u64::from(params.width * params.height),
            "the colony must have swallowed lineages for the census to say anything: {live:?}"
        );
        assert_eq!(rescored.distinct_lineages, live.distinct_lineages);
        assert_eq!(rescored.top_lineage_share, live.top_lineage_share);
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
