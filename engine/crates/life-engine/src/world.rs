//! The world: cells, one epoch of the substrate's rule, the observables, snapshots and
//! rendering. A run is fully determined by `(params, seed)` — every draw comes from a
//! stream keyed by the seed and the epoch, so a world restored from a snapshot continues
//! exactly as the uninterrupted run would have.

use crate::bff;
use crate::hash::{fnv1a64, fnv1a64_of};
use crate::metrics::{self, Metrics, TransitionTracker};
use crate::params::{Init, Interaction, LineageRule, ParamError, Params, Substrate};
use crate::render;
use crate::replicator;
use crate::rng::{self, Rng};
use crate::snapshot::{self, SnapshotError};

const STREAM_INIT: u64 = 0;
const STREAM_STEP: u64 = 1;
const STREAM_REPLICATOR: u64 = 2;
/// The stream the census's repeat draws are keyed on, kept far from the small stream ids
/// above so a draw can never collide with one. Draw 0 keeps `STREAM_REPLICATOR`, which is
/// what the census has always drawn on, so `replicator_count` reads exactly what it read
/// before the repeats existed.
const STREAM_REPLICATOR_DRAW: u64 = 0x5245_5043_0000_0000;
/// How many independent assays one census runs. The test is four Bernoulli trials against
/// random partners, so one draw is a coin toss on a marginal tape and a run's census
/// flickers between adjacent samples (`docs/design_record.md`, 2026-09-18). Module-private
/// and not a parameter: it is how an observable is read, not something a sweep varies.
const CENSUS_DRAWS: u32 = 8;
/// The streams the orientation-aware companions of the census draw on: the cells sampled
/// for `replicator_share` and their chains' noise, and the dominant tape's chains. Far from
/// every other stream id, so the companions never move a draw the run or the census makes
/// (`docs/design_record.md`, 2026-09-25).
const STREAM_SELF_REP: u64 = 0x5345_4c46_0000_0000;
const STREAM_SELF_REP_DOMINANT: u64 = STREAM_SELF_REP | 1;
/// The stream `copy_latency`'s trials draw their noise partners on — its own, far from
/// every id above, so the latency moves no draw the run, the census or the detector makes
/// (`docs/design_record.md`, 2026-09-25).
const STREAM_COPY_LATENCY: u64 = 0x4c41_5445_0000_0000;

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
    /// The `steal_rate` of that same epoch, counted in the same pass.
    steal_rate: f64,
    /// The `reverse_copy_rate` of that same epoch, counted in the same pass.
    reverse_copy_rate: f64,
    /// One lineage id per cell, unique at init and inherited by descent in `step_soup`.
    /// Empty on the life substrate. A tag is read and written beside the tapes and never
    /// from the RNG stream, so a run's bytes are what they were before lineages existed.
    lineages: Vec<u64>,
    /// The live length of each cell's tape (DESIGN §1.3, sweep 8). Empty — and every tape
    /// fills its `stride`-wide slot — unless this run's tapes can grow, so a world that
    /// cannot allocates nothing and is read exactly as it was before lengths existed.
    lens: Vec<u32>,
    /// The instruction energy each cell holds (DESIGN §1.1, `energy_influx`). Unlike the
    /// per-epoch allowance this carries across epochs, so it is state of the world: it is
    /// hashed, snapshotted and restored. Empty — and never read — unless this run has an
    /// influx, so a run without one is the run it always was.
    stock: Vec<u32>,
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
            steal_rate: 0.0,
            reverse_copy_rate: 0.0,
            lineages: fresh_lineages(params),
            lens: fresh_lens(params),
            stock: fresh_stock(params),
        };
        if params.init == Init::Random {
            let mut rng = rng::seeded(seed, STREAM_INIT, 0);
            let alphabet = world.params.substrate;
            let lens = &world.lens;
            for (cell, slot) in world.cells.chunks_mut(params.stride()).enumerate() {
                let live = lens.get(cell).map_or(slot.len(), |len| *len as usize);
                for byte in &mut slot[..live] {
                    *byte = draw_cell_byte(&mut rng, alphabet);
                }
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

    /// The state of one cell: a whole tape in the soup, one `0`/`1` byte in life. On a
    /// world whose tapes can grow this is the cell's live bytes, not its whole slot.
    pub fn cell(&self, x: u32, y: u32) -> &[u8] {
        self.tape(self.index(x, y))
    }

    /// The lineage id of one cell: the ancestor its tape descends from by copying
    /// (`docs/DESIGN.md` §1.2). 0 on the life substrate, which carries no lineages.
    pub fn lineage(&self, x: u32, y: u32) -> u64 {
        self.lineages.get(self.index(x, y)).copied().unwrap_or(0)
    }

    /// Panics unless `bytes` fits one cell: exactly the slot on a world whose tapes cannot
    /// grow, and anything from one byte up to the cap on one whose tapes can.
    pub fn set_cell(&mut self, x: u32, y: u32, bytes: &[u8]) {
        let stride = self.params.stride();
        if self.lens.is_empty() {
            assert_eq!(bytes.len(), stride, "a cell holds {stride} bytes");
        } else {
            assert!(
                (1..=stride).contains(&bytes.len()),
                "a cell holds 1 to {stride} bytes"
            );
        }
        let cell = self.index(x, y);
        let at = cell * stride;
        self.cells[at..at + stride].fill(0);
        self.cells[at..at + bytes.len()].copy_from_slice(bytes);
        if let Some(len) = self.lens.get_mut(cell) {
            *len = bytes.len() as u32;
        }
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
        let compressed = metrics::compress_ratio(&self.tapes().bytes());
        self.sample(compressed)
    }

    /// The same sample as `metrics` and the same snapshot as `snapshot`, taken together
    /// at an epoch whose cadences coincide: `compress_ratio` and the snapshot's payload
    /// are one and the same zlib stream over the cells, so it is produced once.
    pub fn metrics_with_snapshot(&mut self) -> (Metrics, Vec<u8>) {
        let (payload, compressed) = {
            let live = self.tapes().bytes();
            let payload = metrics::compress(&live);
            let compressed = metrics::compress_ratio_of(payload.len(), live.len());
            (payload, compressed)
        };
        let measured = self.sample(compressed);
        (
            measured,
            snapshot::encode_compressed(
                &self.snapshot_header(),
                &payload,
                &self.lineages,
                &self.lens,
                &self.stock,
            ),
        )
    }

    pub fn transition_epoch(&self) -> Option<u64> {
        self.transition.epoch()
    }

    /// The transition read against this run's own baseline rather than the constant
    /// threshold, a companion to the locked `transition_epoch` above and never a
    /// replacement for it (`docs/design_record.md`, 2026-09-19).
    pub fn transition_epoch_relative(&self) -> Option<u64> {
        self.transition.relative_epoch()
    }

    /// The hash of every byte the world holds, padding included — and after them, where
    /// tapes can grow, the lengths, and where cells hold energy, the stocks: the same bytes
    /// under two different sets of lengths, or two different stocks, are two different
    /// worlds. A world with neither hashes the bytes alone, as it always did.
    pub fn world_hash(&self) -> u64 {
        if self.lens.is_empty() && self.stock.is_empty() {
            return fnv1a64(&self.cells);
        }
        let (lens, stock) = (words(&self.lens), words(&self.stock));
        fnv1a64_of([self.cells.as_slice(), lens.as_slice(), stock.as_slice()])
    }

    pub fn snapshot(&self) -> Vec<u8> {
        snapshot::encode(
            &self.snapshot_header(),
            &self.tapes().bytes(),
            &self.lineages,
            &self.lens,
            &self.stock,
        )
    }

    /// The world's cells read as tapes: the flat array of slots, and the live lengths
    /// wherever they can differ from it.
    fn tapes(&self) -> metrics::Tapes<'_> {
        metrics::Tapes::ragged(&self.cells, self.params.stride(), &self.lens)
    }

    fn tape(&self, cell: usize) -> &[u8] {
        let at = cell * self.params.stride();
        &self.cells[at..at + self.live_len(cell)]
    }

    fn live_len(&self, cell: usize) -> usize {
        self.lens
            .get(cell)
            .map_or(self.params.stride(), |len| *len as usize)
    }

    fn snapshot_header(&self) -> snapshot::Header {
        snapshot::Header {
            substrate: self.params.substrate,
            width: self.params.width,
            height: self.params.height,
            tape_len: self.params.tape_len,
            tape_cap: self.params.tape_cap(),
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
            steal_rate: 0.0,
            reverse_copy_rate: 0.0,
            lineages: restored.lineages.unwrap_or_else(|| fresh_lineages(params)),
            lens: restored.lens.unwrap_or_else(|| fresh_lens(params)),
            stock: restored_stock(params, restored.stock)?,
        })
    }

    /// A descendant run's world: the stored world of a finished parent, carried on under
    /// `params` and `seed` that may differ from the parent's in dynamics only. The cells,
    /// lineage tags and live lengths carry over — a lineage of the parent is a lineage of
    /// the child — and the stocks are re-read against the child's economy
    /// (`descended_stock`). The transition tracker starts fresh: a descendant is not
    /// measured for the transition its parent already made, and its start lies past the
    /// baseline window, so its relative reading has no baseline and reads nothing — that is
    /// why a world still inside the window is refused rather than descended. Neither
    /// reading of the parent's transition carries over; the child's own constant reading
    /// is measured like any run's.
    ///
    /// Under the parent's own params and seed the descendant is the parent continued,
    /// byte for byte: the RNG is keyed by seed, stream and epoch and holds no state.
    pub fn descend(params: &Params, seed: u64, bytes: &[u8]) -> Result<Self, SnapshotError> {
        let restored = snapshot::decode_for_descent(params, bytes)?;
        let epoch = restored.header.epoch;
        if epoch <= metrics::TRANSITION_BASELINE_EPOCHS {
            return Err(SnapshotError::InsideBaselineWindow { epoch });
        }
        Ok(Self {
            params: params.clone(),
            seed,
            epoch,
            cells: restored.cells,
            scratch: life_scratch(params),
            transition: TransitionTracker::default(),
            copy_rate: 0.0,
            steal_rate: 0.0,
            reverse_copy_rate: 0.0,
            lineages: restored.lineages.unwrap_or_else(|| fresh_lineages(params)),
            lens: restored.lens.unwrap_or_else(|| fresh_lens(params)),
            stock: descended_stock(params, restored.stock)?,
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
        let soup = self.params.substrate == Substrate::Soup;
        let (pixels, _) = buf.as_chunks_mut::<{ render::BYTES_PER_PIXEL }>();
        for (cell, pixel) in self.tapes().iter().zip(pixels) {
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
    /// and `reverse_copy_rate` of those interactions. The pre-execution pair is kept every
    /// epoch — the lineage rule reads it — and counting copies adds a few comparisons
    /// per interaction for each rate, so it stays off on every other epoch.
    fn step_soup(&mut self, rng: &mut Rng) {
        let stride = self.params.stride();
        let cap = self.params.tape_cap() as usize;
        let max_steps = self.params.max_steps;
        let ops = self.params.op_set();
        let hosted = self.params.interaction == Interaction::Host;
        let theft = Theft::of(&self.params);
        let counting = self.counts_copies();
        let mut energy = Energy::recharged(&self.params, std::mem::take(&mut self.stock));
        let mut order: Vec<u32> = (0..self.params.cell_count() as u32).collect();
        rng::shuffle(&mut order, rng);

        let mut pair = Vec::with_capacity(stride * 2);
        let mut before = Vec::with_capacity(stride * 2);
        let mut interactions: u64 = 0;
        let mut copies: u64 = 0;
        let mut reversed_copies: u64 = 0;
        let mut thefts: u64 = 0;
        for cell in &order {
            let a = *cell as usize;
            let b = self.pick_partner(a, rng);
            if a == b || energy.starved(a, b) {
                continue;
            }
            let (live_a, live_b) = (self.live_len(a), self.live_len(b));
            pair.clear();
            pair.extend_from_slice(&self.cells[a * stride..a * stride + live_a]);
            pair.extend_from_slice(&self.cells[b * stride..b * stride + live_b]);
            before.clear();
            before.extend_from_slice(&pair);
            let budget = energy.budget(a, b, max_steps);
            // The pair may lengthen to the first tape's length plus a whole second tape at
            // its cap; with no room to grow that is the length it already has. Under a
            // host interaction the instruction pointer stops at the end of the first tape
            // and the partner is data; under the default it stops where the pair does.
            let code_len = if hosted { live_a } else { live_a + cap };
            let bounds = bff::Bounds {
                max_steps: budget,
                enabled: ops,
                cap: live_a + cap,
                code_len,
            };
            let outcome = bff::run_stealing(&mut pair, bounds, Theft::stealing(theft, live_a));
            energy.spend(a, b, outcome.steps);
            if let Some(theft) = theft {
                energy.settle(a, b, outcome.steals, &theft);
            }
            if counting {
                interactions += 1;
                thefts += u64::from(outcome.steals.iter().any(|steals| *steals > 0));
                // A pair that arrives already satisfying the rule cannot show a copy: it
                // ends satisfying it whether or not anything ran. Reading that exclusion
                // as plain inequality would count every frozen pair whose shorter half is
                // its partner's prefix — a tape and the tape one head step lengthened —
                // and read near 1.0 on a monoculture that never moved.
                let (arrived_a, arrived_b) = (&before[..live_a], &before[live_a..]);
                let arrived_copied =
                    copied_onto(arrived_b, arrived_a) || copied_onto(arrived_a, arrived_b);
                let copied = !arrived_copied
                    && (copied_onto(&pair[live_a..], arrived_a)
                        || copied_onto(&pair[..live_a], arrived_b));
                copies += u64::from(copied);
                let arrived_reversed =
                    reversed_onto(arrived_b, arrived_a) || reversed_onto(arrived_a, arrived_b);
                let reversed = !arrived_reversed
                    && (reversed_onto(&pair[live_a..], arrived_a)
                        || reversed_onto(&pair[..live_a], arrived_b));
                reversed_copies += u64::from(reversed);
            }
            // The split stays where the pair was joined: the first cell keeps the length it
            // arrived with, the second keeps the rest — the tail a copier writes into and
            // the only end of the pair that can have grown.
            self.cells[a * stride..a * stride + live_a].copy_from_slice(&pair[..live_a]);
            let grown_b = pair.len() - live_a;
            self.cells[b * stride..b * stride + grown_b].copy_from_slice(&pair[live_a..]);
            if let Some(len) = self.lens.get_mut(b) {
                *len = grown_b as u32;
            }
            self.inherit_lineages(a, b, &pair, &before, live_a);
        }
        self.stock = energy.into_stock();
        if counting {
            let share = |count: u64| match interactions {
                0 => 0.0,
                ran => count as f64 / ran as f64,
            };
            self.copy_rate = share(copies);
            self.steal_rate = share(thefts);
            self.reverse_copy_rate = share(reversed_copies);
        }
    }

    /// Descent, read off the one interaction that just ran: a cell takes its partner's
    /// lineage id when the tape it ends with is closer to the tape its partner arrived
    /// with than to the tape it arrived with itself, and keeps its own on a tie — closer
    /// as the run's `lineage_rule` measures it. Both cells are judged against the pair as
    /// it arrived, so an exchange swaps the two tags rather than collapsing them onto one.
    fn inherit_lineages(&mut self, a: usize, b: usize, pair: &[u8], before: &[u8], split: usize) {
        let rule = self.params.lineage_rule;
        let (was_a, was_b) = (self.lineages[a], self.lineages[b]);
        if inherits_partner(rule, &pair[..split], &before[..split], &before[split..]) {
            self.lineages[a] = was_b;
        }
        if inherits_partner(rule, &pair[split..], &before[split..], &before[..split]) {
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
        let lens = &self.lens;
        for (cell, state) in self.cells.chunks_mut(stride).enumerate() {
            let rate = self
                .params
                .mutation_rate_at(cell as u32 % width, cell as u32 / width);
            let live = lens.get(cell).map_or(state.len(), |len| *len as usize);
            for byte in &mut state[..live] {
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
        let cells = self.params.cell_count() as f64;
        let ranked = metrics::ranked_tapes(self.tapes());
        let top_share = ranked.first().map_or(0.0, |(_, n)| *n as f64 / cells);
        let histogram = metrics::ByteHistogram::of(&self.tapes().bytes());
        let (distinct_lineages, top_lineage_share) = metrics::lineage_census(&self.lineages);
        let census = self.replicator_census(&ranked);
        let core = self.conserved_core();
        let core_oriented = self.conserved_core_oriented();
        let lineage = self.lineage_complexity();
        let share = self.replicator_share();

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
            lineage_variation: metrics::lineage_variation(self.tapes(), &self.lineages),
            copy_cost: census.copy_cost,
            dominant_compressed_len: census.complexity.map(|read| read.compressed_len),
            dominant_instruction_count: census.complexity.map(|read| read.instruction_count),
            dominant_replicates: census.dominant_replicates,
            dominant_raw_len: census.complexity.map(|read| read.raw_len),
            dominant_tape_hash: census.complexity.map(|read| read.tape_hash_hex()),
            conserved_core_bytes: core.map(|read| read.bytes),
            conserved_core_ops: core.map(|read| read.ops),
            steal_rate: self.steal_rate,
            replicator_pass_rate: census.pass_rate(),
            replicator_count_mean: census.count_mean(),
            lineage_compressed_len: lineage.map(|read| read.compressed_len),
            lineage_instruction_count: lineage.map(|read| read.instruction_count),
            reverse_copy_rate: self.reverse_copy_rate,
            replicator_share: share.map(|read| read.aligned),
            replicator_share_rotated: share.map(|read| read.rotated),
            dominant_self_replicates: census.dominant_self_replicates,
            lineage_variation_oriented: metrics::lineage_variation_oriented(
                self.tapes(),
                &self.lineages,
            ),
            conserved_core_bytes_oriented: core_oriented.map(|read| read.bytes),
            conserved_core_ops_oriented: core_oriented.map(|read| read.ops),
            copy_latency: census.copy_latency.map(|image| image.steps),
            copy_latency_orientation: census.copy_latency.map(|image| image.orientation),
        }
    }

    /// The orientation-aware companion of the census: `SELF_REP_SAMPLE_CELLS` cells drawn
    /// uniformly with replacement, each tape put to `replicator::self_replicates`, and the
    /// share that passed. Drawn from the whole world rather than the `top_k` ranked tapes,
    /// which in an emerged world cover a few percent of its cells. Everything — which cells,
    /// and every chain's noise — comes off `STREAM_SELF_REP` at this epoch, and nothing is
    /// written back, so the reading is a pure function of `(seed, epoch)` and moves no other
    /// observable. Life cells have no tape to judge.
    fn replicator_share(&self) -> Option<SelfRepShare> {
        if self.params.substrate != Substrate::Soup {
            return None;
        }
        let mut rng = rng::seeded(self.seed, STREAM_SELF_REP, self.epoch);
        let cells = self.params.cell_count() as u64;
        let (mut aligned, mut rotated) = (0u32, 0u32);
        for _ in 0..replicator::SELF_REP_SAMPLE_CELLS {
            let cell = rng::below(&mut rng, cells) as usize;
            let verdict = self.self_replicates(self.tape(cell), &mut rng);
            aligned += u32::from(verdict.aligned);
            rotated += u32::from(verdict.rotated);
        }
        let share = |passed: u32| f64::from(passed) / f64::from(replicator::SELF_REP_SAMPLE_CELLS);
        Some(SelfRepShare {
            aligned: share(aligned),
            rotated: share(rotated),
        })
    }

    fn self_replicates(&self, tape: &[u8], rng: &mut Rng) -> replicator::Verdict {
        replicator::self_replicates(tape, self.params.max_steps, self.params.op_set(), rng)
    }

    /// How much tape the largest lineage is, read off its modal tape. Life cells carry no
    /// tape and no lineage. Like the conserved core, the reading walks tapes the sample
    /// already holds and draws nothing: no RNG stream moves.
    fn lineage_complexity(&self) -> Option<metrics::Complexity> {
        if self.params.substrate != Substrate::Soup {
            return None;
        }
        metrics::lineage_complexity(self.tapes(), &self.lineages, self.params.op_set())
    }

    /// What the largest lineage holds invariant across its members. Life cells carry no
    /// tape and no lineage, so there is nothing there to conserve. The reading walks the
    /// tapes the census has already ranked and draws nothing: no RNG stream moves.
    fn conserved_core(&self) -> Option<metrics::ConservedCore> {
        if self.params.substrate != Substrate::Soup {
            return None;
        }
        metrics::conserved_core(self.tapes(), &self.lineages, self.params.op_set())
    }

    /// The same core read over members put the way round their lineage's modal tape is.
    fn conserved_core_oriented(&self) -> Option<metrics::ConservedCore> {
        if self.params.substrate != Substrate::Soup {
            return None;
        }
        metrics::conserved_core_oriented(self.tapes(), &self.lineages, self.params.op_set())
    }

    /// Cells holding one of the `top_k` most common tapes that passes the replicator test,
    /// and what the dominant tape costs and carries. The dominant tape is the first tape to
    /// pass — `ranked` being in population order — and, when none of the tested tapes
    /// passes, the most populous tape of the world: after an emergence the copy rate alone
    /// confirmed, the tape most cells hold is the thing that is copying, and a census that
    /// read nothing there left such a run unmeasurable (`docs/design_record.md`,
    /// 2026-09-15). Exactly one tape is compressed per sample, whichever it is. Life cells
    /// are single bits and have no tape to read at all.
    fn replicator_census<'a>(&self, ranked: &[(&'a [u8], u64)]) -> ReplicatorCensus {
        if self.params.substrate != Substrate::Soup {
            return ReplicatorCensus::default();
        }
        let draws: Vec<CensusDraw<'a>> = (0..CENSUS_DRAWS)
            .map(|draw| self.census_draw(ranked, draw))
            .collect();
        let first = &draws[0];
        ReplicatorCensus {
            count: first.count,
            copy_cost: first.copy_cost,
            complexity: first
                .dominant
                .map(|tape| metrics::Complexity::of(tape, self.params.op_set())),
            dominant_replicates: first.dominant_replicates,
            dominant_self_replicates: first.dominant.map(|tape| {
                let mut rng = rng::seeded(self.seed, STREAM_SELF_REP_DOMINANT, self.epoch);
                self.self_replicates(tape, &mut rng).aligned
            }),
            copy_latency: first.dominant.and_then(|tape| {
                let mut rng = rng::seeded(self.seed, STREAM_COPY_LATENCY, self.epoch);
                replicator::copy_latency(
                    tape,
                    self.params.max_steps,
                    self.params.op_set(),
                    &mut rng,
                )
            }),
            counts: draws.iter().map(|draw| draw.count).collect(),
        }
    }

    /// One assay of every ranked tape, on the stream draw `draw` owns. The census reads the
    /// world and writes nothing back — no cell, no lineage and no simulation stream moves —
    /// so a draw is a pure function of `(seed, epoch, draw)` and repeating it cannot change
    /// what the run does next.
    fn census_draw<'a>(&self, ranked: &[(&'a [u8], u64)], draw: u32) -> CensusDraw<'a> {
        let mut rng = rng::seeded(self.seed, census_stream(draw), self.epoch);
        let ops = self.params.op_set();
        let mut read_off = CensusDraw {
            dominant: ranked.first().map(|(tape, _)| *tape),
            ..CensusDraw::default()
        };
        for (tape, cells) in ranked.iter().take(self.params.top_k as usize) {
            let read = replicator::assay(tape, self.params.max_steps, ops, &mut rng);
            if read.replicates() {
                read_off.count += cells;
                if !read_off.dominant_replicates {
                    read_off.dominant_replicates = true;
                    read_off.dominant = Some(*tape);
                }
                read_off.copy_cost = read_off.copy_cost.or(read.copy_cost);
            }
        }
        read_off
    }
}

/// The stream one census draw is seeded on. Draw 0 keeps `STREAM_REPLICATOR` — that is
/// what makes `replicator_count` the same reading every stored sample carries — and the
/// repeats take a stream of their own that the simulation never draws from.
fn census_stream(draw: u32) -> u64 {
    match draw {
        0 => STREAM_REPLICATOR,
        draw => STREAM_REPLICATOR_DRAW | u64::from(draw),
    }
}

/// What one sample's run of the replicator test read: how many cells hold a tape that
/// passed, and the dominant tape's own observables — with whether that tape is one of the
/// passing ones.
#[derive(Default)]
struct ReplicatorCensus {
    count: u64,
    copy_cost: Option<u32>,
    complexity: Option<metrics::Complexity>,
    dominant_replicates: bool,
    /// Whether that same tape passes the orientation-aware detector, on a stream of its
    /// own. `None` on the life substrate.
    dominant_self_replicates: Option<bool>,
    /// When that same tape first completes an image of itself, on a stream of its own.
    copy_latency: Option<bff::Image>,
    /// What each of the `CENSUS_DRAWS` draws counted, draw 0 first — the count above being
    /// that first draw's. Empty on the life substrate, where no assay runs at all.
    counts: Vec<u64>,
}

impl ReplicatorCensus {
    /// The share of draws that found a replicator: 1.0 where a tape passes every assay,
    /// and a fraction where the census is catching a tape at the edge of the test.
    fn pass_rate(&self) -> Option<f64> {
        self.read(|counts| {
            counts.iter().filter(|count| **count > 0).count() as f64 / counts.len() as f64
        })
    }

    fn count_mean(&self) -> Option<f64> {
        self.read(|counts| counts.iter().sum::<u64>() as f64 / counts.len() as f64)
    }

    fn read(&self, of: impl Fn(&[u64]) -> f64) -> Option<f64> {
        match self.counts.is_empty() {
            true => None,
            false => Some(of(&self.counts)),
        }
    }
}

/// The share of sampled cells whose tape passed the orientation-aware detector, read
/// aligned and under the best rotation.
#[derive(Clone, Copy)]
struct SelfRepShare {
    aligned: f64,
    rotated: f64,
}

/// What one assay draw of the census read: the cells it counted, and the dominant tape it
/// picked out with whether that tape passed.
#[derive(Default)]
struct CensusDraw<'a> {
    count: u64,
    copy_cost: Option<u32>,
    dominant: Option<&'a [u8]>,
    dominant_replicates: bool,
}

/// What the epoch's cells may spend on instructions, out of the two economies the
/// substrate offers: the allowance `energy_per_epoch` refills in full every epoch (DESIGN
/// §1.3 sweep 6) and the stock `energy_influx` tops up and execution draws down (DESIGN
/// §1.1). Both are opt-in and independent — a run may have either, both or neither — and
/// an empty purse is what off means: nothing is allocated and nothing bounds an
/// interaction but `max_steps`.
struct Energy {
    allowance: Vec<u32>,
    stock: Vec<u32>,
}

impl Energy {
    /// The epoch's energy: the allowance refilled in full, and the stock the world carried
    /// in topped up by one influx, never past its cap.
    fn recharged(params: &Params, mut stock: Vec<u32>) -> Self {
        for held in &mut stock {
            *held = held
                .saturating_add(params.energy_influx)
                .min(params.energy_stock_cap);
        }
        Self {
            allowance: match params.energy_per_epoch {
                0 => Vec::new(),
                budget => vec![budget; params.cell_count()],
            },
            stock,
        }
    }

    /// How many instructions one interaction may execute: what the poorer of the two cells
    /// has left in each economy it lives under, never more than `max_steps`. Both cells
    /// execute the one concatenated program, so neither can pay past its own energy and the
    /// interaction halts where the poorer one runs dry.
    fn budget(&self, a: usize, b: usize, max_steps: u32) -> u32 {
        [&self.allowance, &self.stock]
            .into_iter()
            .filter(|purse| !purse.is_empty())
            .fold(max_steps, |budget, purse| {
                budget.min(purse[a]).min(purse[b])
            })
    }

    /// Whether either cell of a pair holds an empty stock: it is not executed at all until
    /// the influx has recharged it, which is the one thing the stock does that a per-epoch
    /// allowance cannot — the allowance is whole again next epoch whatever was spent.
    fn starved(&self, a: usize, b: usize) -> bool {
        self.stock.get(a) == Some(&0) || self.stock.get(b) == Some(&0)
    }

    /// Debits both cells of an interaction with the instructions it executed.
    fn spend(&mut self, a: usize, b: usize, steps: u32) {
        for purse in [&mut self.allowance, &mut self.stock] {
            if !purse.is_empty() {
                purse[a] -= steps;
                purse[b] -= steps;
            }
        }
    }

    /// Settles the steal ops one interaction executed, after `spend` has taken what the
    /// interaction cost: the first tape's thefts out of the second cell, then the second
    /// tape's out of the first. Taking theft off what a cell has *left* is what keeps the
    /// two economies apart — an interaction is bounded by the stocks its pair arrived with,
    /// so a cell can never be robbed of energy it has already promised to instructions.
    fn settle(&mut self, a: usize, b: usize, steals: [u32; 2], theft: &Theft) {
        self.rob(a, b, steals[0], theft);
        self.rob(b, a, steals[1], theft);
    }

    /// Settles one half of the pair's steals, one op at a time: each takes what it can out
    /// of what the victim still holds, so the amount a steal moves shrinks as the stock it
    /// takes from does and an emptied victim ends the run early.
    fn rob(&mut self, thief: usize, victim: usize, steals: u32, theft: &Theft) {
        for _ in 0..steals {
            let moved = theft.takes(self.stock[victim]);
            if moved == 0 {
                break;
            }
            self.stock[victim] -= moved;
            self.stock[thief] = self.stock[thief]
                .saturating_add(theft.delivers(moved))
                .min(theft.cap);
        }
    }

    /// The stock, back to the world it came from: it is the half of the epoch's energy
    /// that outlives the epoch.
    fn into_stock(self) -> Vec<u32> {
        self.stock
    }
}

/// What a steal op is worth (`docs/DESIGN.md` §1.1), read off the parameters once per
/// epoch: the energy one steal takes out of the partner's stock and the share of it
/// destroyed in transit. `None` for every run whose `steal_amount` is 0, which is every run
/// at the defaults — the byte is then not an instruction at all and nothing is settled.
#[derive(Debug, Clone, Copy)]
struct Theft {
    amount: u32,
    loss: f64,
    cap: u32,
}

impl Theft {
    fn of(params: &Params) -> Option<Self> {
        params.steals().then_some(Self {
            amount: params.steal_amount,
            loss: params.steal_loss,
            cap: params.energy_stock_cap,
        })
    }

    /// The steal byte as the interpreter should read it over a pair whose first tape ends
    /// at `split`: an instruction where a theft exists at all, the plain no-op where none
    /// does. A theft exists only where the run switched the op on, so this `Option<Theft>`
    /// is the single switch the interpreter and the settlement both read.
    fn stealing(theft: Option<Self>, split: usize) -> bff::Stealing {
        match theft {
            Some(_) => bff::Stealing::At(split),
            None => bff::Stealing::Off,
        }
    }

    /// What one steal op takes out of a partner holding `held`: `steal_amount`, or
    /// everything the partner still has when that is less — an empty partner gives up
    /// nothing, and no steal can take a cell below zero however often it runs.
    fn takes(&self, held: u32) -> u32 {
        self.amount.min(held)
    }

    /// What the thief receives of one steal's `moved`: the share `1 - steal_loss`,
    /// **rounded down**, so theft is never worth more to the thief than the fraction says
    /// and the remainder is energy the world has destroyed. The loss is taken on each op
    /// separately, so a single steal of 1 at a loss of 0.5 delivers nothing at all.
    fn delivers(&self, moved: u32) -> u32 {
        (f64::from(moved) * (1.0 - self.loss)).floor() as u32
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

/// Whether one half of a pair holds a byte-exact image of a tape, read from byte zero
/// (`copy_rate`, DESIGN §1.2). A half too short to hold the whole source is no copy of it;
/// bytes past the image — the room a growing tape claimed and never wrote into — do not
/// unmake one, or an interaction that grew could never register a copy at all. The rule
/// reads the pair as it arrived as well as the pair it left, so a pair that already
/// satisfied it is excluded rather than counted.
fn copied_onto(result: &[u8], source: &[u8]) -> bool {
    result.len() >= source.len() && result[..source.len()] == *source
}

/// `copied_onto` with the image reversed (`reverse_copy_rate`, DESIGN §1.2): the half holds
/// the source's bytes last to first, read from its own first byte over the source's length.
/// A palindrome is its own reverse, so its copy satisfies both rules and counts in both
/// rates.
fn reversed_onto(result: &[u8], source: &[u8]) -> bool {
    result.len() >= source.len() && result[..source.len()].iter().eq(source.iter().rev())
}

/// Whether a tape resembles its partner's arriving tape more closely than its own, by
/// Hamming distance over the tape's bytes — the plainest distance on a fixed-length tape,
/// and the same byte-by-byte reading `copy_rate` makes of an exact copy. A tie keeps the
/// cell's own lineage, so a tape that did not move keeps its tag.
///
/// Under the oriented rule both distances are taken either way round, not only the
/// partner's: measuring one arrival with a reversal allowed and the other without would
/// tilt every close call toward the partner, and a cell whose own bytes came back to it
/// reversed would change lineage although nothing of anyone else's reached it.
fn inherits_partner(rule: LineageRule, result: &[u8], own: &[u8], partner: &[u8]) -> bool {
    match rule {
        LineageRule::Aligned => {
            metrics::hamming_distance(result, partner) < metrics::hamming_distance(result, own)
        }
        LineageRule::Oriented => {
            oriented_distance(result, partner) < oriented_distance(result, own)
        }
    }
}

/// How far a tape is from an arriving tape put whichever way round is nearer to it: the
/// arrival as it came, or its live bytes last to first read from the tape's first byte —
/// the image `reversed_onto` reads a reverse copy as.
fn oriented_distance(result: &[u8], arrived: &[u8]) -> u64 {
    let reversed = result
        .iter()
        .zip(arrived.iter().rev())
        .filter(|(left, right)| left != right)
        .count() as u64
        + result.len().abs_diff(arrived.len()) as u64;
    metrics::hamming_distance(result, arrived).min(reversed)
}

/// A run of `u32`s as the little-endian bytes the world hashes them by.
fn words(values: &[u32]) -> Vec<u8> {
    values
        .iter()
        .flat_map(|value| value.to_le_bytes())
        .collect()
}

/// One id per cell, unique in the world: the cell's own index, so a lineage census at
/// epoch 0 reads one cell per lineage without drawing anything.
fn fresh_lineages(params: &Params) -> Vec<u64> {
    (0..params.lineage_count() as u64).collect()
}

/// One live length per cell, every tape at the length a run starts at — empty, and never
/// read, on a world whose tapes cannot grow.
fn fresh_lens(params: &Params) -> Vec<u32> {
    match params.grows() {
        true => vec![params.tape_len; params.cell_count()],
        false => Vec::new(),
    }
}

/// The stock a resumed run carries. Unlike the lineage tags or the lengths, a stock cannot
/// be minted for a world that was not stored with one: the energy a cell holds is state the
/// run spent epochs arriving at. So stocked params meeting a blob that carries none — and
/// the reverse — are refused the way a diverging tape cap is refused, rather than silently
/// filling or discarding the stocks.
fn restored_stock(params: &Params, stock: Option<Vec<u32>>) -> Result<Vec<u32>, SnapshotError> {
    match (stock, params.stocked()) {
        (None, false) => Ok(fresh_stock(params)),
        (Some(stock), true) if stock.len() == params.cell_count() => Ok(stock),
        (Some(_), true) => Err(SnapshotError::Mismatch {
            field: "cell count",
        }),
        _ => Err(SnapshotError::Mismatch {
            field: "energy_influx",
        }),
    }
}

/// The stock a descendant starts with. A descendant's economy is a treatment, so unlike a
/// resume it may differ from the parent's: a parent that held no energy hands every cell a
/// full stock at the child's cap, as a fresh run starts; a stocked parent under a child
/// with no influx drops its stocks; and a stocked parent under a stocked child keeps each
/// cell's stock, clamped to the child's cap.
fn descended_stock(params: &Params, stock: Option<Vec<u32>>) -> Result<Vec<u32>, SnapshotError> {
    match (stock, params.stocked()) {
        (Some(stock), true) if stock.len() == params.cell_count() => Ok(stock
            .into_iter()
            .map(|held| held.min(params.energy_stock_cap))
            .collect()),
        (Some(_), true) => Err(SnapshotError::Mismatch {
            field: "cell count",
        }),
        _ => Ok(fresh_stock(params)),
    }
}

/// One energy stock per cell, every cell starting the run full — the world begins at the
/// ceiling its cap sets rather than spending its first epochs filling up. Empty, and never
/// read, on a world with no influx.
fn fresh_stock(params: &Params) -> Vec<u32> {
    match params.stocked() {
        true => vec![params.energy_stock_cap; params.cell_count()],
        false => Vec::new(),
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
    use crate::metrics::TransitionState;
    use crate::params::{Interaction, Structure};
    use std::collections::BTreeSet;

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
    /// The tags of that first world, pinned when the lineage rule became a parameter: the
    /// same under both rules there.
    const PINNED_SOUP_LINEAGE_HASH: u64 = 0x4d38_1366_823a_e560;
    /// A mutating reverse-copier colony, where the two lineage rules part
    /// (`mutating_reverse_colony`): its bytes, and its tags under each rule.
    const PINNED_REVERSE_COLONY_HASH: u64 = 0x752c_1e85_b477_d74e;
    const PINNED_REVERSE_COLONY_ALIGNED_LINEAGE_HASH: u64 = 0xe746_36f6_8030_b75c;
    const PINNED_REVERSE_COLONY_ORIENTED_LINEAGE_HASH: u64 = 0xe173_3ed0_0d40_85cc;
    const PINNED_REVERSE_COLONY_ALIGNED_LINEAGES: &str =
        "distinct_lineages=39 top_lineage_share=0.109375";
    const PINNED_REVERSE_COLONY_ORIENTED_LINEAGES: &str =
        "distinct_lineages=15 top_lineage_share=0.1484375";
    /// The replicator readings of those same two worlds, as they read before #192 added a
    /// raw length and a tape hash beside them: the new fields are additive, so every field
    /// a sample already carried has to print the same digits it printed before.
    const PINNED_DOMINANT: &str = "copy_cost=None dominant_compressed_len=Some(75) \
         dominant_instruction_count=Some(3) dominant_replicates=false";
    const PINNED_SEEDED_DOMINANT: &str = "copy_cost=Some(1794) dominant_compressed_len=Some(36) \
         dominant_instruction_count=Some(15) dominant_replicates=true";
    /// And the two fields #192 added, pinned apart from them.
    const PINNED_DOMINANT_TAPE: &str = "dominant_raw_len=Some(64) \
         dominant_tape_hash=Some(\"fdc479506869ad61\")";
    const PINNED_SEEDED_DOMINANT_TAPE: &str = "dominant_raw_len=Some(256) \
         dominant_tape_hash=Some(\"1d895db59f8130fa\")";
    /// And the two fields #193 added, pinned apart again: what the largest lineage of each
    /// of those worlds holds invariant across its members.
    const PINNED_CONSERVED_CORE: &str = "conserved_core_bytes=Some(1) conserved_core_ops=Some(0)";
    const PINNED_SEEDED_CONSERVED_CORE: &str =
        "conserved_core_bytes=Some(253) conserved_core_ops=Some(15)";
    /// And the two fields the eight-draw census added (`docs/design_record.md`,
    /// 2026-09-18), pinned apart once more: `replicator_count` above stays draw 0.
    const PINNED_CENSUS_DRAWS: &str = "replicator_pass_rate=Some(0.0) \
         replicator_count_mean=Some(0.0)";
    const PINNED_SEEDED_CENSUS_DRAWS: &str = "replicator_pass_rate=Some(1.0) \
         replicator_count_mean=Some(196.0)";
    /// And the two fields #175 added, pinned apart once more: the complexity of the
    /// largest lineage's representative, beside the dominant tape's above.
    const PINNED_LINEAGE_COMPLEXITY: &str =
        "lineage_compressed_len=Some(75) lineage_instruction_count=Some(4)";
    const PINNED_SEEDED_LINEAGE_COMPLEXITY: &str =
        "lineage_compressed_len=Some(39) lineage_instruction_count=Some(15)";

    /// And the four orientation-aware companions (`docs/design_record.md`, 2026-09-25),
    /// pinned apart from every reading above, which they must not move.
    const PINNED_SELF_REP: &str = "reverse_copy_rate=0.0 replicator_share=Some(0.0) \
         replicator_share_rotated=Some(0.0) dominant_self_replicates=Some(false)";
    const PINNED_SEEDED_SELF_REP: &str = "reverse_copy_rate=0.0 \
         replicator_share=Some(0.99609375) replicator_share_rotated=Some(0.99609375) \
         dominant_self_replicates=Some(true)";

    /// And the five oriented companions of the lineage readings and of `copy_cost`
    /// (`docs/design_record.md`, 2026-09-25), pinned apart again.
    const PINNED_ORIENTED: &str = "lineage_variation_oriented=31.5 \
         conserved_core_bytes_oriented=Some(1) conserved_core_ops_oriented=Some(0) \
         copy_latency=None copy_latency_orientation=None";
    const PINNED_SEEDED_ORIENTED: &str = "lineage_variation_oriented=0.8623853211009175 \
         conserved_core_bytes_oriented=Some(253) conserved_core_ops_oriented=Some(15) \
         copy_latency=Some(1790) copy_latency_orientation=Some(Forward)";

    fn oriented_digest(measured: &Metrics) -> String {
        format!(
            "lineage_variation_oriented={:?} conserved_core_bytes_oriented={:?} \
             conserved_core_ops_oriented={:?} copy_latency={:?} copy_latency_orientation={:?}",
            measured.lineage_variation_oriented,
            measured.conserved_core_bytes_oriented,
            measured.conserved_core_ops_oriented,
            measured.copy_latency,
            measured.copy_latency_orientation,
        )
    }

    fn self_rep_digest(measured: &Metrics) -> String {
        format!(
            "reverse_copy_rate={:?} replicator_share={:?} replicator_share_rotated={:?} \
             dominant_self_replicates={:?}",
            measured.reverse_copy_rate,
            measured.replicator_share,
            measured.replicator_share_rotated,
            measured.dominant_self_replicates,
        )
    }

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

    /// The replicator readings of a sample as they were before #192, read apart from the
    /// digests above for the same reason those two are apart: each was pinned in its own
    /// era and cannot carry the fields of a later one.
    fn dominant_digest(measured: &Metrics) -> String {
        format!(
            "copy_cost={:?} dominant_compressed_len={:?} dominant_instruction_count={:?} \
             dominant_replicates={}",
            measured.copy_cost,
            measured.dominant_compressed_len,
            measured.dominant_instruction_count,
            measured.dominant_replicates,
        )
    }

    fn dominant_tape_digest(measured: &Metrics) -> String {
        format!(
            "dominant_raw_len={:?} dominant_tape_hash={:?}",
            measured.dominant_raw_len, measured.dominant_tape_hash,
        )
    }

    fn census_digest(measured: &Metrics) -> String {
        format!(
            "replicator_pass_rate={:?} replicator_count_mean={:?}",
            measured.replicator_pass_rate, measured.replicator_count_mean,
        )
    }

    fn lineage_complexity_digest(measured: &Metrics) -> String {
        format!(
            "lineage_compressed_len={:?} lineage_instruction_count={:?}",
            measured.lineage_compressed_len, measured.lineage_instruction_count,
        )
    }

    fn conserved_core_digest(measured: &Metrics) -> String {
        format!(
            "conserved_core_bytes={:?} conserved_core_ops={:?}",
            measured.conserved_core_bytes, measured.conserved_core_ops,
        )
    }

    fn soup(width: u32, height: u32) -> Params {
        Params {
            width,
            height,
            ..Params::default()
        }
    }

    /// The 16×16 soup half filled with the handwritten replicator, seed 7, stepped to the
    /// first sample — the world the seeded pins above were read on.
    fn seeded_world() -> World {
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
        world
    }

    fn stocked_params() -> Params {
        Params {
            max_steps: 64,
            energy_influx: 8,
            energy_stock_cap: 64,
            ..soup(16, 16)
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

    /// And with room to grow: a tape's length is written by the interaction that grew it
    /// and never drawn, so a run resumed from a snapshot lengthens exactly as the
    /// uninterrupted one did.
    #[test]
    fn determinism_holds_with_room_to_grow() {
        for max_tape_len in [64, 96, 256] {
            for seed in [1, 2, 3] {
                assert_deterministic(
                    &Params {
                        tape_len: 64,
                        max_tape_len,
                        mutation_rate: 1.0 / 256.0,
                        ..soup(16, 16)
                    },
                    seed,
                );
            }
        }
    }

    /// And under an energy stock, which — unlike the per-epoch allowance — is state of the
    /// world rather than a function of the epoch: a run resumed from a snapshot must carry
    /// the stocks the snapshot was written with, or it would recharge from a fuller world
    /// than the uninterrupted one held.
    #[test]
    fn determinism_holds_under_an_energy_stock() {
        for (energy_influx, energy_stock_cap) in [(8, 64), (64, 4096)] {
            for seed in [1, 2, 3] {
                assert_deterministic(
                    &Params {
                        energy_influx,
                        energy_stock_cap,
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
        assert_eq!(dominant_digest(&measured), PINNED_DOMINANT);
        assert_eq!(dominant_tape_digest(&measured), PINNED_DOMINANT_TAPE);
        assert_eq!(conserved_core_digest(&measured), PINNED_CONSERVED_CORE);
        assert_eq!(census_digest(&measured), PINNED_CENSUS_DRAWS);
        assert_eq!(
            lineage_complexity_digest(&measured),
            PINNED_LINEAGE_COMPLEXITY
        );
        assert_eq!(self_rep_digest(&measured), PINNED_SELF_REP);
        assert_eq!(oriented_digest(&measured), PINNED_ORIENTED);
    }

    #[test]
    fn the_observables_of_a_seeded_soup_read_what_they_read_before_lineage_tags() {
        let mut world = seeded_world();
        let measured = world.metrics();
        assert_eq!(observable_digest(&measured), PINNED_SEEDED_OBSERVABLES);
        assert_eq!(lineage_digest(&measured), PINNED_SEEDED_LINEAGES);
        assert_eq!(dominant_digest(&measured), PINNED_SEEDED_DOMINANT);
        assert_eq!(dominant_tape_digest(&measured), PINNED_SEEDED_DOMINANT_TAPE);
        assert_eq!(
            conserved_core_digest(&measured),
            PINNED_SEEDED_CONSERVED_CORE
        );
        assert_eq!(census_digest(&measured), PINNED_SEEDED_CENSUS_DRAWS);
        assert_eq!(
            lineage_complexity_digest(&measured),
            PINNED_SEEDED_LINEAGE_COMPLEXITY
        );
        assert_eq!(self_rep_digest(&measured), PINNED_SEEDED_SELF_REP);
        assert_eq!(oriented_digest(&measured), PINNED_SEEDED_ORIENTED);
    }

    /// The census only reads the world: it draws on streams of its own, moves no cell and
    /// writes nothing back, so measuring the same epoch again — or measuring it again on a
    /// world rebuilt from that epoch's snapshot — reads the same draws.
    #[test]
    fn a_repeated_census_reads_the_same_pass_rate_twice() {
        let mut world = seeded_world();
        let measured = world.metrics();
        let again = world.metrics();

        assert_eq!(
            (
                measured.replicator_pass_rate,
                measured.replicator_count_mean
            ),
            (again.replicator_pass_rate, again.replicator_count_mean)
        );

        let mut restored =
            World::from_snapshot(world.params(), world.seed(), &world.snapshot()).unwrap();
        let reread = restored.metrics();

        assert_eq!(
            (
                measured.replicator_pass_rate,
                measured.replicator_count_mean
            ),
            (reread.replicator_pass_rate, reread.replicator_count_mean)
        );
    }

    /// `replicator_count` stays what it always was — the cells one draw counted, on the
    /// stream that draw has always used — so a sample taken today is comparable with every
    /// sample in the record. The mean is the reading beside it, not a replacement.
    #[test]
    fn the_first_draw_is_the_census_the_count_has_always_reported() {
        let mut world = seeded_world();
        let measured = world.metrics();

        assert_eq!(measured.replicator_count, 196);
        assert_eq!(measured.replicator_pass_rate, Some(1.0));
        assert_eq!(measured.replicator_count_mean, Some(196.0));
    }

    /// What makes the repeats independent, and `replicator_count` the reading it always
    /// was: draw 0 is seeded on the stream the census has drawn on since it existed, and
    /// the seven repeats take seven streams of their own that the simulation never draws
    /// from. No world can show this — a world whose census reads the same count on every
    /// stream is exactly the world the pins above are taken on — so it is read off the
    /// seeding itself.
    #[test]
    fn the_first_census_draw_keeps_the_stream_the_count_has_always_been_seeded_on() {
        let streams: Vec<u64> = (0..CENSUS_DRAWS).map(census_stream).collect();

        assert_eq!(streams[0], STREAM_REPLICATOR);
        assert_eq!(
            streams.iter().collect::<BTreeSet<_>>().len(),
            CENSUS_DRAWS as usize,
            "{streams:?}"
        );
        for stream in &streams[1..] {
            assert!(
                ![STREAM_INIT, STREAM_STEP, STREAM_REPLICATOR].contains(stream),
                "{stream:#x} is a stream the simulation draws from"
            );
        }
    }

    /// The two readings over a census whose draws disagree: the share of draws that found
    /// anything, and the mean of what they counted.
    #[test]
    fn a_census_whose_draws_disagree_reads_a_fraction_of_a_pass_rate() {
        let census = ReplicatorCensus {
            counts: vec![0, 12, 0, 8, 0, 0, 0, 0],
            ..ReplicatorCensus::default()
        };

        assert_eq!(census.pass_rate(), Some(0.25));
        assert_eq!(census.count_mean(), Some(2.5));
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
            inherits_partner(LineageRule::Aligned, b"wxyz", b"abcd", b"wxyz"),
            "an exact copy of the partner's arriving tape inherits"
        );
        assert!(
            !inherits_partner(LineageRule::Aligned, b"abcd", b"abcd", b"wxyz"),
            "a tape that did not move keeps its own tag"
        );
        assert!(
            !inherits_partner(LineageRule::Aligned, b"abcz", b"abcd", b"wxyz"),
            "one byte from its own arrival, three from the partner's: keeps its own"
        );
        assert!(
            !inherits_partner(LineageRule::Aligned, b"abyz", b"abcd", b"wxyz"),
            "two bytes from each arrival is a tie, and a tie keeps its own"
        );
    }

    /// A reverse copy of `A` over a cell of lineage `B` is aligned-far from `A` — here as
    /// far as it is from `B` — so the aligned rule leaves the cell `B`, and the oriented
    /// rule reads it as `A`'s descendant.
    #[test]
    fn a_reverse_copy_takes_the_copiers_tag_only_under_the_oriented_rule() {
        let (copier, own) = (b"abcdefgh", b"stuvwxyz");
        let reversed = b"hgfedcba";
        assert!(!inherits_partner(
            LineageRule::Aligned,
            reversed,
            own,
            copier
        ));
        assert!(inherits_partner(
            LineageRule::Oriented,
            reversed,
            own,
            copier
        ));
    }

    /// A forward copy, a cell that did not move and a partial overwrite read the same
    /// under both rules when no arriving tape is nearer reversed.
    #[test]
    fn a_forward_copy_reads_the_same_under_both_rules() {
        for (result, expected) in [
            (b"abcdefgh", true),
            (b"stuvwxyz", false),
            (b"abcdefyz", true),
            (b"abcdwxyz", false),
        ] {
            for rule in [LineageRule::Aligned, LineageRule::Oriented] {
                assert_eq!(
                    inherits_partner(rule, result, b"stuvwxyz", b"abcdefgh"),
                    expected,
                    "{rule:?} {:?}",
                    std::str::from_utf8(result)
                );
            }
        }
    }

    /// A palindrome is its own reverse, so its copy inherits under both rules; and the
    /// oriented rule keeps the aligned rule's tie: strictly closer, or the cell keeps its
    /// own tag.
    #[test]
    fn a_palindrome_inherits_under_both_rules_and_a_tie_keeps_the_cells_own_tag() {
        for rule in [LineageRule::Aligned, LineageRule::Oriented] {
            assert!(inherits_partner(
                rule,
                b"abcddcba",
                b"stuvwxyz",
                b"abcddcba"
            ));
        }
        assert!(
            !inherits_partner(LineageRule::Oriented, b"abyz", b"abcd", b"wxyz"),
            "two bytes from each arrival either way round is a tie"
        );
        assert!(
            !inherits_partner(LineageRule::Oriented, b"dcyz", b"abcd", b"zyxw"),
            "two bytes from each arrival once both are reversed is a tie too"
        );
    }

    /// The own tape is read either way round as well: a cell whose own bytes came back to
    /// it reversed descends from itself, and keeps its tag.
    #[test]
    fn a_cell_holding_its_own_tape_reversed_keeps_its_tag_under_the_oriented_rule() {
        assert!(!inherits_partner(
            LineageRule::Oriented,
            b"hgfedcbx",
            b"abcdefgh",
            b"hgfedcyz"
        ));
        assert!(inherits_partner(
            LineageRule::Aligned,
            b"hgfedcbx",
            b"abcdefgh",
            b"hgfedcyz"
        ));
    }

    /// The oriented rule reads a tape and its reverse as one tape: a cell holding `X`
    /// that ends an exact forward copy of a partner holding `reverse(X)` is at distance 0
    /// from both arrivals, a tie, and keeps its own tag; the aligned rule hands it over.
    #[test]
    fn a_tape_and_its_reverse_are_one_tape_under_the_oriented_rule() {
        let (own, partner) = (b"abcdefgh", b"hgfedcba");
        assert!(inherits_partner(
            LineageRule::Aligned,
            partner,
            own,
            partner
        ));
        assert!(!inherits_partner(
            LineageRule::Oriented,
            partner,
            own,
            partner
        ));
    }

    /// A tape that grew is set against the reverse of the live bytes its partner arrived
    /// with, read from its own first byte; the bytes it gained count against both.
    #[test]
    fn the_oriented_distance_reads_live_bytes_of_a_ragged_pair() {
        assert_eq!(oriented_distance(b"cbaxy", b"abc"), 2);
        assert_eq!(oriented_distance(b"abcxy", b"abc"), 2);
        assert_eq!(oriented_distance(b"cb", b"abc"), 1);
        assert!(inherits_partner(
            LineageRule::Oriented,
            b"cbaxy",
            b"zzzzz",
            b"abc"
        ));
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

    /// A world of two lineages whose largest lineage's representative is not the tape most
    /// cells hold: nine cells of lineage 1 — five of them on a tape half made of
    /// instructions, four on a run of one byte — beside seven cells of lineage 2 on a run
    /// of another. Lineage 1 is the largest and its modal tape is the five-cell one; the
    /// world's most populous tape is lineage 2's seven, and it holds no instruction and
    /// compresses further.
    fn two_lineage_world() -> World {
        const TAPE_LEN: u32 = 32;

        let params = Params {
            tape_len: TAPE_LEN,
            mutation_rate: 0.0,
            ..soup(4, 4)
        };
        let representative: Vec<u8> = (0..TAPE_LEN as usize)
            .map(|at| {
                if at % 2 == 0 {
                    bff::OPS[at / 2 % bff::OPS.len()]
                } else {
                    b'A' + at as u8
                }
            })
            .collect();
        let minority = vec![b'b'; TAPE_LEN as usize];
        let populous = vec![b'a'; TAPE_LEN as usize];

        let mut world = World::new(&params, 5).unwrap();
        let cells = [
            [
                &representative,
                &representative,
                &representative,
                &representative,
            ],
            [&representative, &minority, &minority, &minority],
            [&minority, &populous, &populous, &populous],
            [&populous, &populous, &populous, &populous],
        ];
        for (y, row) in cells.iter().enumerate() {
            for (x, tape) in row.iter().enumerate() {
                world.set_cell(x as u32, y as u32, tape);
            }
        }
        world.lineages = (0..params.cell_count())
            .map(|cell| if cell < 9 { 1 } else { 2 })
            .collect();
        world
    }

    /// The point of the lineage reading: the dominant tape is whichever tape most cells
    /// hold at this sample, so a lineage whose modal tape is not that one is invisible
    /// through it (`docs/design_record.md`, 2026-09-19).
    #[test]
    fn the_lineage_complexity_reads_a_different_tape_than_the_dominant_one() {
        let mut world = two_lineage_world();
        let measured = world.metrics();

        assert_eq!(measured.distinct_lineages, 2);
        assert!(!measured.dominant_replicates);
        assert_eq!(measured.dominant_instruction_count, Some(0));
        assert_eq!(measured.lineage_instruction_count, Some(16));
        assert_ne!(
            measured.lineage_compressed_len,
            measured.dominant_compressed_len
        );
    }

    /// The representative is a function of the world alone, so a run resumed from a
    /// snapshot reads the tape the run that wrote it read.
    #[test]
    fn a_resumed_world_reads_the_same_lineage_complexity() {
        let mut world = two_lineage_world();
        let measured = world.metrics();

        let mut restored =
            World::from_snapshot(world.params(), world.seed(), &world.snapshot()).unwrap();
        let reread = restored.metrics();

        assert_eq!(
            (
                measured.lineage_compressed_len,
                measured.lineage_instruction_count
            ),
            (
                reread.lineage_compressed_len,
                reread.lineage_instruction_count
            )
        );
    }

    #[test]
    fn a_life_world_carries_no_lineages() {
        let mut world = World::new(&life(4, 4), 1).unwrap();
        let measured = world.metrics();
        assert_eq!(measured.distinct_lineages, 0);
        assert_eq!(measured.top_lineage_share, 0.0);
        assert_eq!(measured.lineage_variation, 0.0);
        assert_eq!(measured.conserved_core_bytes, None);
        assert_eq!(measured.conserved_core_ops, None);
    }

    #[test]
    fn a_life_world_reads_nothing_of_a_dominant_replicator() {
        let mut world = World::new(&life(4, 4), 1).unwrap();
        let measured = world.metrics();
        assert_eq!(measured.replicator_count, 0);
        assert_eq!(measured.copy_cost, None);
        assert_eq!(measured.dominant_compressed_len, None);
        assert_eq!(measured.dominant_instruction_count, None);
        assert_eq!(measured.dominant_raw_len, None);
        assert_eq!(measured.dominant_tape_hash, None);
        assert_eq!(measured.replicator_pass_rate, None);
        assert_eq!(measured.replicator_count_mean, None);
        assert_eq!(measured.lineage_compressed_len, None);
        assert_eq!(measured.lineage_instruction_count, None);
        assert!(!measured.dominant_replicates);
        assert_eq!(measured.replicator_share, None);
        assert_eq!(measured.replicator_share_rotated, None);
        assert_eq!(measured.dominant_self_replicates, None);
        assert_eq!(measured.lineage_variation_oriented, 0.0);
        assert_eq!(measured.conserved_core_bytes_oriented, None);
        assert_eq!(measured.conserved_core_ops_oriented, None);
        assert_eq!(measured.copy_latency, None);
        assert_eq!(measured.copy_latency_orientation, None);
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
            steals: [0, 0],
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
            let outcome = bff::Outcome {
                halt,
                steps: 4,
                steals: [0, 0],
            };
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

    /// The stock's gate, read off the energy itself: an interaction runs on the poorer of
    /// the two stocks, and a cell that has spent its last instruction is starved — passed
    /// over entirely — until the next epoch's influx has recharged it.
    #[test]
    fn an_empty_stock_starves_a_pair_until_the_next_influx() {
        let params = Params {
            energy_influx: 4,
            energy_stock_cap: 16,
            ..soup(4, 4)
        };
        let mut energy = Energy::recharged(&params, vec![0, 8, 16, 16]);
        assert!(!energy.starved(0, 1));
        assert_eq!(energy.budget(0, 1, 64), 4, "the poorer of the two stocks");

        energy.spend(0, 1, 4);
        assert!(
            energy.starved(0, 1),
            "a cell that spent its last instruction was executed again"
        );
        assert!(!energy.starved(2, 3));

        let next = Energy::recharged(&params, energy.into_stock());
        assert!(!next.starved(0, 1), "an influx left a cell starved");
        assert_eq!(next.budget(2, 3, 64), 16, "a stock filled past its cap");
    }

    /// And in the world: with an influx worth exactly one interaction, a cell the epoch's
    /// earlier interactions emptied executes nothing at all on its own turn, and runs again
    /// only once the next influx has paid it back.
    #[test]
    fn a_cell_emptied_by_its_neighbours_runs_again_once_the_influx_recharges_it() {
        let stock = Params {
            energy_influx: ADDING_INTERACTION_STEPS,
            energy_stock_cap: ADDING_INTERACTION_STEPS,
            ..adding_params()
        };
        let mut world = adding_soup(&stock);
        world.step();
        let first = increments(&world);
        assert!(
            first.iter().all(|paid| *paid <= ADDING_INTERACTION_STEPS),
            "a cell paid past its stock: {first:?}"
        );
        let emptied: Vec<usize> = (0..first.len()).filter(|at| first[*at] == 0).collect();
        assert!(
            !emptied.is_empty(),
            "no cell was emptied before its own turn came: {first:?}"
        );

        world.step();
        let second = increments(&world);
        assert!(
            emptied.iter().any(|at| second[*at] > first[*at]),
            "a cell emptied in one epoch never ran again: {first:?} then {second:?}"
        );
        assert!(
            (0..first.len()).all(|at| second[at] - first[at] <= ADDING_INTERACTION_STEPS),
            "an epoch paid past the stock the influx could fill: {first:?} then {second:?}"
        );
    }

    /// A cell passed over for an empty stock is passed over in the epoch's census too: the
    /// pair never ran, so it is in neither half of `copy_rate` (DESIGN §1.2). Eight of the
    /// fifty-three pairs that ran in this epoch copied; the eleven the stock starved are in
    /// neither number. Were they counted as interactions that copied nothing, the rate
    /// would read 8/64 — every starving epoch diluted by however many cells ran dry.
    #[test]
    fn a_starved_pair_is_in_neither_half_of_the_epochs_copy_rate() {
        let params = Params {
            sample_every: 1,
            energy_influx: 64,
            energy_stock_cap: 8192,
            ..colony_params()
        };
        assert_eq!(params.cell_count(), 64);

        let mut world = colony(&params, 3);
        world.step();

        assert!(
            world.stock.contains(&0),
            "no cell was starved, so the epoch counted nothing either way"
        );
        assert_eq!(world.metrics().copy_rate, 8.0 / 53.0);
    }

    /// What separates the stock from the per-epoch allowance: the allowance is whole again
    /// next epoch however it was spent, so under it every cell runs every epoch, while
    /// under a stock the same influx buys a cell nothing it has already spent.
    #[test]
    fn what_a_stock_leaves_unspent_is_what_the_next_epoch_adds_to() {
        const INFLUX: u32 = 4;
        let stock = Params {
            energy_influx: INFLUX,
            energy_stock_cap: 4 * ADDING_INTERACTION_STEPS,
            ..adding_params()
        };
        let mut world = adding_soup(&stock);
        let mut paid = Vec::new();
        for _ in 0..4 {
            world.step();
            paid.push(increments(&world));
        }
        let ceiling = |epoch: u32| stock.energy_stock_cap + epoch * INFLUX;
        for (epoch, counted) in paid.iter().enumerate() {
            assert!(
                counted.iter().all(|spent| *spent <= ceiling(epoch as u32)),
                "a cell spent more than every epoch so far gave it: {counted:?}"
            );
        }

        let mut allowance = adding_soup(&Params {
            energy_influx: 0,
            energy_stock_cap: 0,
            energy_per_epoch: INFLUX,
            ..stock.clone()
        });
        for _ in 0..4 {
            allowance.step();
        }
        assert_ne!(
            increments(&allowance),
            *paid.last().expect("four epochs"),
            "a carried stock ran the world exactly as a refilled allowance did"
        );
    }

    /// The stock is opt-in: naming it off — and naming a cap with no influx to fill it —
    /// must leave a run exactly where the parameters' absence left it, down to the bytes of
    /// the world and every observable of §1.2.
    #[test]
    fn the_energy_stock_switched_off_moves_no_run() {
        let off = Params {
            energy_influx: 0,
            energy_stock_cap: 4096,
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

    /// And switched on it is a different world: the same seed under an influx no cell can
    /// spend freely runs a soup the defaults never reach.
    #[test]
    fn a_run_under_an_energy_stock_is_not_the_run_at_the_defaults() {
        let params = Params {
            max_steps: 64,
            ..soup(16, 16)
        };
        let free = stepped(&params, 42, 20);
        let stocked = stepped(
            &Params {
                energy_influx: 8,
                energy_stock_cap: 64,
                ..params.clone()
            },
            42,
            20,
        );
        assert_ne!(stocked.world_hash(), free.world_hash());
    }

    /// A stock no epoch can spend — every cell could pay for a full-length interaction many
    /// times over and the influx keeps it there — has to read as the soup with the stock
    /// off: the accounting itself must not move a byte.
    #[test]
    fn an_unspendable_energy_stock_runs_the_soup_unchanged() {
        let params = Params {
            max_steps: 64,
            energy_influx: 1_048_576,
            energy_stock_cap: 1_048_576,
            ..soup(16, 16)
        };
        let stocked = stepped(&params, 42, 20);
        let free = stepped(
            &Params {
                energy_influx: 0,
                energy_stock_cap: 0,
                ..params.clone()
            },
            42,
            20,
        );
        assert_eq!(stocked.tapes().bytes(), free.tapes().bytes());
    }

    /// The three optional economies of §1.1 compose: a run may carry a stock, a per-epoch
    /// allowance and room to grow at once, every one of them binding what an interaction
    /// executes, and the run is still none of the runs with one of them switched off.
    #[test]
    fn a_stock_composes_with_the_per_epoch_allowance_and_room_to_grow() {
        let all = Params {
            max_steps: 64,
            energy_per_epoch: 80,
            energy_influx: 16,
            energy_stock_cap: 128,
            tape_len: 64,
            max_tape_len: 96,
            mutation_rate: 1.0 / 256.0,
            ..soup(16, 16)
        };
        assert_eq!(all.validate(), Ok(()));
        assert_deterministic(&all, 7);

        let tapes = stepped(&all, 7, 20).tapes().bytes().into_owned();
        for without in [
            Params {
                energy_influx: 0,
                energy_stock_cap: 0,
                ..all.clone()
            },
            Params {
                energy_per_epoch: 0,
                ..all.clone()
            },
            Params {
                max_tape_len: 0,
                ..all.clone()
            },
        ] {
            assert_ne!(
                stepped(&without, 7, 20).tapes().bytes().into_owned(),
                tapes,
                "switching one economy off left the world where all three had it: {without:?}"
            );
        }
    }

    /// A soup whose every byte is one inert value: nothing executes, so the tapes are
    /// frozen and every difference between two such worlds is a difference in the energy.
    fn soup_of(params: &Params, byte: u8) -> World {
        let mut world = World::new(params, 3).unwrap();
        let tape = vec![byte; params.stride()];
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }
        world
    }

    fn held_energy(world: &World) -> u64 {
        world.stock.iter().map(|held| u64::from(*held)).sum()
    }

    fn theft(amount: u32, loss: f64, cap: u32) -> Theft {
        Theft { amount, loss, cap }
    }

    fn purse(stock: Vec<u32>) -> Energy {
        Energy {
            allowance: Vec::new(),
            stock,
        }
    }

    /// The rule of §1.1: one steal takes `steal_amount` out of the partner's stock and the
    /// thief receives all but the `steal_loss` share of it, the rest destroyed.
    #[test]
    fn a_steal_moves_the_amount_and_destroys_the_loss() {
        let mut energy = purse(vec![0, 40]);
        energy.settle(0, 1, [1, 0], &theft(10, 0.25, 64));

        assert_eq!(
            energy.stock,
            vec![7, 30],
            "10 left the partner and 7 arrived"
        );

        let mut both = purse(vec![40, 40]);
        both.settle(0, 1, [2, 1], &theft(10, 0.5, 64));
        assert_eq!(
            both.stock,
            vec![40, 25],
            "the first tape's two steals settled before the second tape's one"
        );
    }

    /// Each steal is its own transfer, and the loss is taken on each: three steals of 1 at
    /// a loss of half deliver nothing at all, where the same movement read as one transfer
    /// of 3 would have delivered 1. The rounding is what makes a small amount pure
    /// destruction, and a sweep has to pick an amount and a loss with a per-op yield.
    #[test]
    fn the_loss_is_taken_on_each_steal_and_not_on_their_sum() {
        let mut energy = purse(vec![0, 8]);
        energy.settle(0, 1, [3, 0], &theft(1, 0.5, 64));

        assert_eq!(
            energy.stock,
            vec![0, 5],
            "3 left the partner and the thief received none of it"
        );
    }

    /// An empty partner is nothing to take: the interaction still ran the op and still paid
    /// its step, and no energy is minted out of a cell that has none.
    #[test]
    fn a_steal_against_an_empty_partner_moves_nothing() {
        let mut energy = purse(vec![12, 0]);
        energy.settle(0, 1, [4, 0], &theft(10, 0.25, 64));

        assert_eq!(energy.stock, vec![12, 0]);
    }

    /// And a partner with less than the amount gives up what it has and no more, however
    /// many steals the interaction ran: the first takes the remainder and the rest find an
    /// empty cell.
    #[test]
    fn a_partner_poorer_than_the_amount_gives_up_only_what_it_holds() {
        let mut energy = purse(vec![0, 4]);
        energy.settle(0, 1, [3, 0], &theft(10, 0.25, 64));

        assert_eq!(energy.stock, vec![3, 0], "4 moved and 1 was destroyed");
    }

    /// Stolen energy is a gain like any other, so the cap bounds it: the world's total
    /// energy still never passes cell count × `energy_stock_cap`.
    #[test]
    fn a_thiefs_stock_never_passes_the_cap() {
        let mut energy = purse(vec![60, 40]);
        energy.settle(0, 1, [1, 0], &theft(20, 0.0, 64));

        assert_eq!(energy.stock, vec![64, 20]);
    }

    fn thieving_params() -> Params {
        Params {
            tape_len: 8,
            mutation_rate: 0.0,
            energy_influx: 4_096,
            energy_stock_cap: 4_096,
            steal_amount: 1,
            steal_loss: 0.5,
            interaction: Interaction::Host,
            ..soup(8, 8)
        }
    }

    /// The op is opt-in, and off it is the plain no-op every other non-instruction byte is:
    /// a soup of nothing but `$` runs the epoch a soup of any other inert byte runs, down
    /// to the energy every cell holds — with the stock on and with it off.
    #[test]
    fn the_steal_op_switched_off_moves_no_energy() {
        for (energy_influx, energy_stock_cap) in [(0, 0), (8, 64)] {
            let off = Params {
                steal_amount: 0,
                energy_influx,
                energy_stock_cap,
                ..thieving_params()
            };
            assert_eq!(off.validate(), Ok(()));

            let mut thieves = soup_of(&off, bff::STEAL);
            let mut inert = soup_of(&off, b'a');
            for _ in 0..off.sample_every {
                thieves.step();
                inert.step();
            }

            assert_eq!(thieves.stock, inert.stock, "{off:?}");
            assert_eq!(
                thieves.tapes().bytes().into_owned(),
                vec![bff::STEAL; off.cell_count() * off.stride()],
                "a disabled steal wrote a byte: {off:?}"
            );
            assert_eq!(thieves.metrics().steal_rate, 0.0);
        }
    }

    /// And naming it off must leave a run of the substrate exactly where the parameter's
    /// absence left it, down to the bytes of the world and every observable of §1.2.
    #[test]
    fn the_steal_op_switched_off_moves_no_run() {
        let off = Params {
            steal_amount: 0,
            steal_loss: 0.9,
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
        assert_eq!(measured.steal_rate, 0.0);
    }

    /// Switched on, theft is a drain on the world and not only a transfer. The baseline is
    /// the same soup of a byte that is not an instruction: it runs the same interactions
    /// for the same steps and so is charged exactly the same energy, and every difference
    /// left is what the steals moved and the loss destroyed.
    #[test]
    fn a_soup_of_thieves_destroys_the_energy_it_moves() {
        let params = thieving_params();
        assert_eq!(params.validate(), Ok(()));

        let mut thieves = soup_of(&params, bff::STEAL);
        let mut honest = soup_of(&params, b'a');
        thieves.step();
        honest.step();

        assert!(
            held_energy(&thieves) < held_energy(&honest),
            "the steals moved and destroyed nothing: {} against a soup that never stole's {}",
            held_energy(&thieves),
            held_energy(&honest)
        );
        assert!(
            thieves
                .stock
                .iter()
                .zip(&honest.stock)
                .any(|(stolen_from, untouched)| stolen_from < untouched),
            "no cell was any poorer for being stolen from"
        );
    }

    /// `steal_rate` (DESIGN §1.2): the share of the sampled epoch's interactions in which a
    /// steal executed. Half this world's cells are thieves and the other half inert, and
    /// only the visited cell's code runs under a `host` interaction, so exactly half of the
    /// 64 interactions steal — while a world with no thief in it reads 0.
    #[test]
    fn the_steal_rate_reads_the_share_of_interactions_that_stole() {
        let params = thieving_params();
        let mut world = soup_of(&params, b'a');
        let thief = vec![bff::STEAL; params.stride()];
        for y in 0..params.height / 2 {
            for x in 0..params.width {
                world.set_cell(x, y, &thief);
            }
        }
        for _ in 0..params.sample_every {
            world.step();
        }

        assert_eq!(world.metrics().steal_rate, 0.5);

        let mut honest = soup_of(&params, b'a');
        for _ in 0..params.sample_every {
            honest.step();
        }
        assert_eq!(honest.metrics().steal_rate, 0.0);
    }

    /// A run that steals is determined by `(params, seed)` like every other: the energy a
    /// steal moves is written by the interaction that ran it and never drawn, and it is
    /// state of the world, so a run resumed from a snapshot carries the stocks theft left.
    #[test]
    fn determinism_holds_under_a_steal_op() {
        for (steal_amount, steal_loss) in [(1, 0.0), (64, 0.5), (4_096, 1.0)] {
            assert_deterministic(
                &Params {
                    energy_influx: 64,
                    energy_stock_cap: 4_096,
                    steal_amount,
                    steal_loss,
                    ..soup(16, 16)
                },
                11,
            );
        }
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

    /// The asymmetric mode of §1.1: at `host` only the first tape's bytes are code, so a
    /// pair runs a different program from the one the concatenation ran and the same seed
    /// reaches a world the default substrate never reaches.
    #[test]
    fn a_host_run_is_not_the_run_at_the_defaults() {
        let params = soup(16, 16);
        let concat = stepped(&params, 42, 20);
        let hosted = stepped(
            &Params {
                interaction: Interaction::Host,
                ..params
            },
            42,
            20,
        );
        assert_ne!(hosted.world_hash(), concat.world_hash());
    }

    /// And the default mode is the substrate every earlier run lived in, down to the byte:
    /// naming it must not move a run.
    #[test]
    fn the_concatenated_interaction_moves_no_run() {
        let concat = Params {
            interaction: Interaction::Concat,
            ..soup(32, 32)
        };
        let mut world = World::new(&concat, 42).unwrap();
        for _ in 0..50 {
            world.step();
        }
        assert_eq!(world.world_hash(), PINNED_SOUP_HASH);

        let measured = world.metrics();
        assert_eq!(observable_digest(&measured), PINNED_OBSERVABLES);
        assert_eq!(lineage_digest(&measured), PINNED_LINEAGES);
    }

    /// A host run is determined by `(params, seed)` like every other, with room to grow on
    /// so the bound and the lengthening pair are exercised together.
    #[test]
    fn determinism_holds_under_an_asymmetric_interaction() {
        assert_deterministic(
            &Params {
                interaction: Interaction::Host,
                max_tape_len: 96,
                ..soup(16, 16)
            },
            11,
        );
    }

    fn tape_lengths(world: &World) -> Vec<usize> {
        (0..world.height())
            .flat_map(|y| (0..world.width()).map(move |x| (x, y)))
            .map(|(x, y)| world.cell(x, y).len())
            .collect()
    }

    fn roomy_soup(max_tape_len: u32) -> Params {
        Params {
            tape_len: 64,
            max_tape_len,
            ..soup(32, 32)
        }
    }

    /// The claim of DESIGN §1.3 sweep 8: with a cap above `tape_len` the soup's own
    /// programs lengthen their tapes, and none of them passes the cap.
    #[test]
    fn a_soup_with_room_to_grow_lengthens_its_tapes() {
        let params = roomy_soup(256);
        let world = stepped(&params, 42, 50);
        let lengths = tape_lengths(&world);

        assert!(
            lengths.iter().any(|len| *len > 64),
            "no tape grew: {lengths:?}"
        );
        assert!(lengths.iter().all(|len| (64..=256).contains(len)));

        // A tape that only claimed bytes would be zero past its initial length; one whose
        // programs wrote into the space they claimed is not.
        let wrote_into_the_room = (0..world.height())
            .flat_map(|y| (0..world.width()).map(move |x| (x, y)))
            .any(|(x, y)| world.cell(x, y)[64..].iter().any(|byte| *byte != 0));
        assert!(wrote_into_the_room, "nothing was written past tape_len");
    }

    #[test]
    fn a_tape_never_shortens() {
        let mut world = World::new(&roomy_soup(128), 7).unwrap();
        let mut lengths = tape_lengths(&world);
        for _ in 0..20 {
            world.step();
            let now = tape_lengths(&world);
            assert!(
                now.iter().zip(&lengths).all(|(now, was)| now >= was),
                "a tape shortened: {lengths:?} then {now:?}"
            );
            lengths = now;
        }
        assert!(lengths.iter().any(|len| *len > 64));
    }

    /// Off is off twice over: `max_tape_len` 0 and a cap at the length every tape already
    /// has are the same run as the soup of §1.1, digit for digit.
    #[test]
    fn room_to_grow_switched_off_moves_no_run() {
        for max_tape_len in [0, 64] {
            let params = Params {
                max_tape_len,
                ..soup(32, 32)
            };
            let mut world = World::new(&params, 42).unwrap();
            for _ in 0..50 {
                world.step();
            }
            assert_eq!(world.world_hash(), PINNED_SOUP_HASH, "cap {max_tape_len}");

            let measured = world.metrics();
            assert_eq!(observable_digest(&measured), PINNED_OBSERVABLES);
            assert_eq!(lineage_digest(&measured), PINNED_LINEAGES);
        }
    }

    /// A world that cannot grow writes the fixed-length container, and a world capped at
    /// the length it already has writes the very same bytes as one with no cap at all: the
    /// cap is not part of a world that never uses it.
    #[test]
    fn a_world_that_cannot_grow_writes_the_fixed_length_container() {
        let fixed = stepped(&soup(8, 8), 9, 4).snapshot();
        let capped = stepped(
            &Params {
                max_tape_len: 64,
                ..soup(8, 8)
            },
            9,
            4,
        )
        .snapshot();
        assert_eq!(fixed[4], snapshot::VERSION_RELATIVE);
        assert_eq!(fixed, capped);
    }

    #[test]
    fn a_snapshot_of_a_grown_world_round_trips_and_the_run_continues_identically() {
        let params = roomy_soup(128);
        let mut world = World::new(&params, 5).unwrap();
        for _ in 0..30 {
            world.step();
        }
        assert!(tape_lengths(&world).iter().any(|len| *len > 64));

        let bytes = world.snapshot();
        assert_eq!(bytes[4], snapshot::VERSION_RELATIVE_RAGGED);
        let mut restored = World::from_snapshot(&params, 5, &bytes).unwrap();
        assert_eq!(tape_lengths(&restored), tape_lengths(&world));
        assert_eq!(restored.world_hash(), world.world_hash());
        assert_eq!(restored.metrics(), world.metrics());

        world.step();
        restored.step();
        assert_eq!(restored.world_hash(), world.world_hash());
    }

    /// The same bytes under two different sets of lengths are two different worlds, and a
    /// hash that read the slots alone would call them one. A tape that claimed bytes
    /// without writing to them is exactly that case: its slot holds what the shorter tape
    /// it grew from holds, zeros past the live bytes either way.
    #[test]
    fn the_world_hash_reads_the_lengths_as_well_as_the_bytes() {
        let params = roomy_soup(128);
        let mut shorter = World::new(&params, 5).unwrap();
        let mut claimed = World::new(&params, 5).unwrap();
        let grown: Vec<u8> = [vec![7u8; 32], vec![0u8; 64]].concat();
        shorter.set_cell(0, 0, &grown[..32]);
        claimed.set_cell(0, 0, &grown);

        assert_eq!(
            shorter.cells, claimed.cells,
            "the two worlds hold one array"
        );
        assert_eq!(shorter.lens[0] + 64, claimed.lens[0]);
        assert_ne!(shorter.world_hash(), claimed.world_hash());
    }

    /// Two worlds holding one array of bytes whose cells hold different energy are two
    /// different worlds: the stock is state, and a hash blind to it would read a run
    /// resumed with full cells as the run that had spent them.
    #[test]
    fn the_world_hash_reads_the_energy_stocks_as_well_as_the_bytes() {
        let params = Params {
            energy_influx: 4,
            energy_stock_cap: 64,
            ..soup(4, 4)
        };
        let world = World::new(&params, 5).unwrap();
        let mut spent = world.clone();
        spent.stock[0] -= 1;

        assert_eq!(world.cells, spent.cells, "the two worlds hold one array");
        assert_ne!(world.world_hash(), spent.world_hash());
    }

    /// A mixed-length world is read on its live bytes alone: the zeros a slot holds past a
    /// tape are not a byte of the world, and an observable that counted them would read a
    /// short tape as a long one padded with zeros.
    #[test]
    fn the_observables_read_the_live_bytes_of_a_mixed_length_world() {
        let params = Params {
            tape_len: 8,
            max_tape_len: 32,
            mutation_rate: 0.0,
            ..soup(4, 4)
        };
        let mut mixed = World::new(&params, 1).unwrap();
        let mut short = World::new(
            &Params {
                max_tape_len: 0,
                ..params.clone()
            },
            1,
        )
        .unwrap();
        let tape: Vec<u8> = (1..=8).collect();
        for y in 0..params.height {
            for x in 0..params.width {
                mixed.set_cell(x, y, &tape);
                short.set_cell(x, y, &tape);
            }
        }
        mixed.set_cell(0, 0, &(1..=24).collect::<Vec<u8>>());

        let measured = mixed.metrics();
        assert_eq!(measured.alphabet_size, 24, "no padding zero was counted");
        assert_eq!(
            measured.distinct_tapes, 2,
            "a grown tape is not the tape it grew from"
        );
        assert_eq!(measured.top_share, 15.0 / 16.0);
        assert_eq!(short.metrics().alphabet_size, 8);
    }

    #[test]
    fn rendering_reads_the_live_tape_of_a_grown_cell() {
        let params = Params {
            tape_len: 8,
            max_tape_len: 32,
            ..soup(4, 4)
        };
        let mut world = World::new(&params, 1).unwrap();
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &[b'+'; 8]);
            }
        }
        world.set_cell(1, 0, &[b'+'; 24]);
        let mut buf = vec![0u8; params.cell_count() * render::BYTES_PER_PIXEL];
        world.render_rgba(&mut buf);

        let grown = [b'+'; 24];
        assert_eq!(
            buf[render::BYTES_PER_PIXEL..2 * render::BYTES_PER_PIXEL],
            render::soup_pixel(&grown, metrics::op_density(&grown)),
            "the pixel is read off the live tape, not the zero-padded slot"
        );
    }

    #[test]
    fn pinned_soup_determinism() {
        let mut world = World::new(&soup(32, 32), 42).unwrap();
        for _ in 0..50 {
            world.step();
        }
        assert_eq!(world.world_hash(), PINNED_SOUP_HASH);
    }

    fn lineage_hash(world: &World) -> u64 {
        let ids: Vec<u8> = world
            .lineages
            .iter()
            .flat_map(|id| id.to_le_bytes())
            .collect();
        fnv1a64(&ids)
    }

    /// A 16×16 soup half seeded with the handwritten reverse replicator, under the default
    /// mutation rate, stepped 50 epochs under `rule`.
    fn mutating_reverse_colony(rule: LineageRule) -> World {
        let params = Params {
            tape_len: 64,
            lineage_rule: rule,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 5).unwrap();
        let tape = replicator::handwritten_reverse_replicator(64);
        for y in 0..params.height / 2 {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }
        for _ in 0..50 {
            world.step();
        }
        world
    }

    /// The oriented lineage rule on the pinned soup: it moves no byte, so the world is the
    /// pinned one exactly. On this world no interaction in 50 epochs leaves a tape nearer
    /// an arrival reversed, so the tags are the aligned rule's too; a larger random soup
    /// can already part on a handful of cells.
    #[test]
    fn pinned_lineage_determinism_of_a_random_soup_under_the_oriented_rule() {
        let params = Params {
            lineage_rule: LineageRule::Oriented,
            ..soup(32, 32)
        };
        let mut world = World::new(&params, 42).unwrap();
        for _ in 0..50 {
            world.step();
        }
        assert_eq!(world.world_hash(), PINNED_SOUP_HASH);
        assert_eq!(lineage_hash(&world), PINNED_SOUP_LINEAGE_HASH);
        assert_eq!(lineage_digest(&world.metrics()), PINNED_LINEAGES);
    }

    /// And on a mutating colony of reverse copiers, where the two rules part: the same
    /// bytes under both, and two different sets of tags — the oriented rule reading the
    /// colony as fewer, larger lineages.
    #[test]
    fn pinned_lineage_determinism_of_a_reverse_colony_under_the_oriented_rule() {
        let mut aligned = mutating_reverse_colony(LineageRule::Aligned);
        let mut oriented = mutating_reverse_colony(LineageRule::Oriented);
        assert_eq!(oriented.world_hash(), aligned.world_hash());
        assert_eq!(oriented.world_hash(), PINNED_REVERSE_COLONY_HASH);
        assert_eq!(
            lineage_hash(&aligned),
            PINNED_REVERSE_COLONY_ALIGNED_LINEAGE_HASH
        );
        assert_eq!(
            lineage_hash(&oriented),
            PINNED_REVERSE_COLONY_ORIENTED_LINEAGE_HASH
        );
        assert_eq!(
            lineage_digest(&aligned.metrics()),
            PINNED_REVERSE_COLONY_ALIGNED_LINEAGES
        );
        assert_eq!(
            lineage_digest(&oriented.metrics()),
            PINNED_REVERSE_COLONY_ORIENTED_LINEAGES
        );
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
            &TransitionState::default(),
            &world.cells,
        );
        let mut restored = World::from_snapshot(&params, 5, &older).unwrap();

        assert_eq!(restored.world_hash(), world.world_hash());
        assert_eq!(restored.epoch(), world.epoch());
        assert_eq!(restored.metrics().distinct_lineages, 64);
    }

    /// A stocked run resumes on the stocks it was stored with: the snapshot's version 5
    /// payload is the world's energy, not a formality, and the restored world is the
    /// stored world byte for byte.
    #[test]
    fn a_stocked_run_resumes_the_stocks_the_snapshot_carried() {
        let params = stocked_params();
        let world = stepped(&params, 11, 12);
        assert!(
            world
                .stock
                .iter()
                .any(|held| *held < params.energy_stock_cap),
            "the run must have spent something for the stocks to say anything: {:?}",
            world.stock
        );

        let restored = World::from_snapshot(&params, 11, &world.snapshot()).unwrap();

        assert_eq!(restored.stock, world.stock);
        assert_eq!(restored.world_hash(), world.world_hash());
    }

    /// Params that hold energy cannot resume a blob that carries none: minting full stocks
    /// for it would hand every cell energy the stored run never had. The same refusal the
    /// tape cap gets.
    #[test]
    fn refuses_a_stocked_resume_of_a_snapshot_that_carries_no_stocks() {
        let unstocked = soup(16, 16);
        let bytes = stepped(&unstocked, 11, 4).snapshot();

        assert!(matches!(
            World::from_snapshot(&stocked_params(), 11, &bytes),
            Err(SnapshotError::Mismatch {
                field: "energy_influx"
            })
        ));
    }

    /// And params with no influx cannot resume a blob that carries stocks: the run that
    /// wrote it was gated by energy this one would silently throw away.
    #[test]
    fn refuses_an_unstocked_resume_of_a_snapshot_that_carries_stocks() {
        let stocked = stocked_params();
        let bytes = stepped(&stocked, 11, 4).snapshot();
        let without_influx = Params {
            energy_influx: 0,
            ..stocked
        };

        assert!(matches!(
            World::from_snapshot(&without_influx, 11, &bytes),
            Err(SnapshotError::Mismatch {
                field: "energy_influx"
            })
        ));
    }

    /// Past the baseline window, where a descendant can start, on a world small and cheap
    /// enough to step there.
    const DESCENT_EPOCH: u64 = metrics::TRANSITION_BASELINE_EPOCHS + 10;

    fn descent_params() -> Params {
        Params {
            width: 8,
            height: 8,
            ..stocked_params()
        }
    }

    fn unstocked(params: &Params) -> Params {
        Params {
            energy_influx: 0,
            energy_stock_cap: 0,
            ..params.clone()
        }
    }

    /// The continuation arm: a child under its parent's params and seed is the parent
    /// carried on — cells, lineages and stocks — since no stream holds state of its own.
    /// The parent is a stocked colony, so by the descent its lineage census has moved off
    /// the one-id-per-cell a fresh world mints and a child that dropped it would show.
    #[test]
    fn a_descendant_with_its_parents_params_and_seed_continues_the_parent() {
        let params = Params {
            energy_influx: 8,
            energy_stock_cap: 64,
            ..colony_params()
        };
        let mut parent = colony(&params, 11);
        for _ in 0..DESCENT_EPOCH {
            parent.step();
        }
        assert_ne!(parent.lineages, fresh_lineages(&params));
        let mut child = World::descend(&params, 11, &parent.snapshot()).unwrap();
        assert_eq!(child.epoch(), DESCENT_EPOCH);

        for _ in 0..20 {
            parent.step();
            child.step();
        }

        assert_eq!(child.epoch(), parent.epoch());
        assert_eq!(child.lineages, parent.lineages);
        assert_eq!(child.stock, parent.stock);
        assert_eq!(child.world_hash(), parent.world_hash());
    }

    #[test]
    fn two_descendants_with_different_seeds_diverge() {
        let params = descent_params();
        let blob = stepped(&params, 11, DESCENT_EPOCH).snapshot();
        let mut one = World::descend(&params, 11, &blob).unwrap();
        let mut other = World::descend(&params, 12, &blob).unwrap();

        for _ in 0..5 {
            one.step();
            other.step();
        }

        assert_ne!(one.world_hash(), other.world_hash());
    }

    #[test]
    fn an_unstocked_parent_descends_into_a_full_stock() {
        let stocked = descent_params();
        let blob = stepped(&unstocked(&stocked), 11, DESCENT_EPOCH).snapshot();

        let child = World::descend(&stocked, 11, &blob).unwrap();

        assert_eq!(
            child.stock,
            vec![stocked.energy_stock_cap; stocked.cell_count()]
        );
    }

    #[test]
    fn a_stocked_parent_descends_into_no_stock() {
        let stocked = descent_params();
        let blob = stepped(&stocked, 11, DESCENT_EPOCH).snapshot();

        let child = World::descend(&unstocked(&stocked), 11, &blob).unwrap();

        assert!(child.stock.is_empty());
    }

    #[test]
    fn a_stocked_parent_descends_into_its_stocks_clamped_to_the_childs_cap() {
        let stocked = descent_params();
        let parent = stepped(&stocked, 11, DESCENT_EPOCH);
        let tighter = Params {
            energy_stock_cap: stocked.energy_influx * 2,
            ..stocked.clone()
        };
        assert!(
            parent
                .stock
                .iter()
                .any(|held| *held > tighter.energy_stock_cap),
            "some cell must hold more than the tighter cap: {:?}",
            parent.stock
        );

        let child = World::descend(&tighter, 11, &parent.snapshot()).unwrap();

        let clamped: Vec<u32> = parent
            .stock
            .iter()
            .map(|held| (*held).min(tighter.energy_stock_cap))
            .collect();
        assert_eq!(child.stock, clamped);
    }

    /// A parent that transitioned long ago, on both readings: resumed, it reports both
    /// epochs; descended, it reports neither, and the child has no baseline to read its
    /// already-compressible start against.
    #[test]
    fn a_descendant_reports_no_transition_of_its_parent() {
        let params = Params {
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(16, 16)
        };
        let restored = snapshot::decode(&params, &quiet_diverse_soup(&params).snapshot()).unwrap();
        let header = snapshot::Header {
            epoch: 600,
            transition: metrics::TransitionState {
                settled: Some(100),
                last_epoch: Some(598),
                relative: metrics::RelativeState {
                    baseline_sum: 0.98,
                    baseline_count: 1,
                    settled: Some(550),
                    ..metrics::RelativeState::default()
                },
                ..metrics::TransitionState::default()
            },
            ..restored.header
        };
        let blob = snapshot::encode(
            &header,
            &restored.cells,
            &restored.lineages.unwrap_or_default(),
            &restored.lens.unwrap_or_default(),
            &restored.stock.unwrap_or_default(),
        );
        let resumed = World::from_snapshot(&params, 3, &blob).unwrap();
        assert_eq!(resumed.transition_epoch(), Some(100));
        assert_eq!(resumed.transition_epoch_relative(), Some(550));

        let mut child = World::descend(&params, 3, &blob).unwrap();
        assert_eq!(child.transition_epoch(), None);
        for _ in 0..8 {
            child.step();
            child.metrics();
            assert_eq!(child.transition_epoch_relative(), None);
            assert!(
                child.transition_epoch().is_none_or(|epoch| epoch > 600),
                "{:?}",
                child.transition_epoch()
            );
        }
    }

    #[test]
    fn a_descendant_with_a_different_tape_cap_is_refused() {
        let blob = stepped(&roomy_soup(96), 11, 2).snapshot();

        assert!(matches!(
            World::descend(&roomy_soup(128), 11, &blob),
            Err(SnapshotError::Mismatch {
                field: "max_tape_len"
            })
        ));
    }

    /// The lineage rule is dynamics: a descendant may switch it, and the switch moves no
    /// byte of the parent's world — only which tags the next copies carry.
    #[test]
    fn a_descendant_may_switch_its_lineage_rule() {
        let params = colony_params();
        let mut parent = colony(&params, 11);
        for _ in 0..DESCENT_EPOCH {
            parent.step();
        }
        let oriented = Params {
            lineage_rule: LineageRule::Oriented,
            ..params
        };
        let mut child = World::descend(&oriented, 11, &parent.snapshot()).unwrap();
        assert_eq!(child.lineages, parent.lineages);

        for _ in 0..20 {
            parent.step();
            child.step();
        }

        assert_eq!(child.world_hash(), parent.world_hash());
    }

    #[test]
    fn a_descendant_of_a_different_width_is_refused() {
        let params = descent_params();
        let blob = stepped(&params, 11, DESCENT_EPOCH).snapshot();
        let wider = Params {
            width: params.width * 2,
            ..params
        };

        assert!(matches!(
            World::descend(&wider, 11, &blob),
            Err(SnapshotError::Mismatch { field: "width" })
        ));
    }

    /// Inside the baseline window the child's relative baseline would be read on the
    /// parent's world, so there is no descending from it.
    #[test]
    fn a_world_inside_its_baseline_window_cannot_be_descended_from() {
        let params = descent_params();
        let blob = stepped(&params, 11, metrics::TRANSITION_BASELINE_EPOCHS).snapshot();

        assert!(matches!(
            World::descend(&params, 11, &blob),
            Err(SnapshotError::InsideBaselineWindow { epoch: 500 })
        ));
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
        assert!(
            !measured.dominant_replicates,
            "no tape passed the replicator test"
        );
        assert_eq!(
            (
                measured.dominant_compressed_len,
                measured.dominant_instruction_count
            ),
            most_populous_complexity(&world),
            "the dominant reading is of the most populous tape all the same"
        );
        assert_eq!(measured.copy_rate, 0.0, "nothing has interacted yet");
        assert!((measured.top_share - 1.0 / 256.0).abs() < 1e-9);
    }

    /// The complexity of the tape the most cells hold, read outside the sample's own census.
    fn most_populous_complexity(world: &World) -> (Option<u32>, Option<u32>) {
        let ranked = metrics::ranked_tapes(world.tapes());
        let read = metrics::Complexity::of(ranked[0].0, world.params.op_set());
        (Some(read.compressed_len), Some(read.instruction_count))
    }

    /// A run can cross into life on `copy_rate` alone, with nothing among the `top_k`
    /// passing the replicator test at the samples that follow. The dominant tape is a tape
    /// either way, and its size is the reading the open-endedness finding needs.
    #[test]
    fn the_dominant_tape_is_read_whether_or_not_it_replicates() {
        let params = Params {
            tape_len: 256,
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(4, 4)
        };
        // An unmatched `]` over non-zero bytes halts a pair at its first instruction, so
        // this is a tape no trial of the replicator test can copy.
        let inert: Vec<u8> = [vec![b']'], vec![b'x'; 255]].concat();
        let mut barren = World::new(&params, 3).unwrap();
        let mut alive = World::new(&params, 3).unwrap();
        for y in 0..params.height {
            for x in 0..params.width {
                barren.set_cell(x, y, &inert);
                alive.set_cell(x, y, &replicator::handwritten_replicator());
            }
        }

        let measured = barren.metrics();
        assert_eq!(measured.replicator_count, 0);
        assert!(!measured.dominant_replicates);
        let read = metrics::Complexity::of(&inert, params.op_set());
        assert_eq!(
            (
                measured.dominant_compressed_len,
                measured.dominant_instruction_count
            ),
            (Some(read.compressed_len), Some(read.instruction_count)),
            "the most populous tape is measured even though nothing replicates"
        );

        let measured = alive.metrics();
        assert!(measured.dominant_replicates);
        assert_eq!(
            (
                measured.dominant_compressed_len,
                measured.dominant_instruction_count
            ),
            (Some(36), Some(15)),
            "and a world of replicators reads its replicator, as it always did"
        );
    }

    /// A compressed length alone cannot be told from a cap: a tape free to lengthen reads
    /// its live length here, so the run page can say what fraction of the tape the
    /// compressed reading is. And the hash is an identity for the tape, so two samples can
    /// be asked whether the dominant tape is still the same one.
    #[test]
    fn the_dominant_reading_carries_the_length_and_the_identity_of_its_own_tape() {
        let params = Params {
            tape_len: 8,
            max_tape_len: 64,
            init: Init::Zero,
            mutation_rate: 0.0,
            ..soup(4, 4)
        };
        let grown: Vec<u8> = (1..=40).collect();
        let mut world = World::new(&params, 3).unwrap();
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &grown);
            }
        }

        let measured = world.metrics();
        let read = metrics::Complexity::of(&grown, params.op_set());
        assert_eq!(
            measured.dominant_raw_len,
            Some(40),
            "the live tape, not the slot it started in"
        );
        assert_eq!(measured.dominant_tape_hash, Some(read.tape_hash_hex()));

        world.set_cell(0, 0, &(2..=41).collect::<Vec<u8>>());
        assert_eq!(
            world.metrics().dominant_tape_hash,
            measured.dominant_tape_hash,
            "one cell of fifteen does not move the dominant tape"
        );

        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &(2..=41).collect::<Vec<u8>>());
            }
        }
        assert_ne!(
            world.metrics().dominant_tape_hash,
            measured.dominant_tape_hash,
            "a world that turned over reads a different tape"
        );
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

    /// A copier writing past the end of a shorter partner lengthens it, so the tape it
    /// leaves behind is its own image plus the byte the last head step claimed. That is a
    /// copy: counting only halves that ended exactly as long as their source would read 0
    /// on every interaction that grew, which is the very arm sweep 8 studies.
    #[test]
    fn a_copy_that_lengthened_its_partner_is_still_a_copy() {
        let params = Params {
            tape_len: 200,
            max_tape_len: 512,
            mutation_rate: 0.0,
            sample_every: 1,
            ..soup(4, 4)
        };
        let mut world = World::new(&params, 3).unwrap();
        let tape = replicator::handwritten_replicator();
        // An unmatched `]` over a non-zero byte halts a pair at its first instruction, so
        // the one interaction of the epoch that executes anything is the copier's.
        let inert: Vec<u8> = [vec![b']'], vec![b'x'; 199]].concat();
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, &inert);
            }
        }
        world.set_cell(0, 0, &tape);

        world.step();

        let grew_a_copy = (0..params.height)
            .flat_map(|y| (0..params.width).map(move |x| (x, y)))
            .map(|(x, y)| world.cell(x, y))
            .any(|cell| cell.len() > tape.len() && cell[..tape.len()] == tape[..]);
        assert!(grew_a_copy, "no partner was copied onto and lengthened");
        assert!(world.metrics().copy_rate > 0.0);
    }

    /// The mixed-length twin of the frozen monoculture below: tapes that differ only in
    /// the byte one of them gained. Nothing runs, yet every such pair satisfies the copy
    /// rule on arrival, so counting them would read half the interactions as copies in a
    /// world that never moved — the bias the rule exists to remove, pointing the other way.
    #[test]
    fn a_frozen_ragged_monoculture_reports_no_copies() {
        let params = Params {
            tape_len: 200,
            max_tape_len: 512,
            mutation_rate: 0.0,
            sample_every: 1,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 3).unwrap();
        let inert: Vec<u8> = [vec![b']'], vec![b'x'; 199]].concat();
        let longer: Vec<u8> = [inert.clone(), vec![b'x']].concat();
        for y in 0..params.height {
            for x in 0..params.width {
                world.set_cell(x, y, if (x + y) % 2 == 0 { &inert } else { &longer });
            }
        }
        let before = world.world_hash();

        world.step();

        assert_eq!(world.world_hash(), before, "nothing moved");
        assert_eq!(
            world.metrics().copy_rate,
            0.0,
            "a half that arrived a copy of its partner is not one"
        );
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
        assert_eq!(
            world.metrics().reverse_copy_rate,
            0.0,
            "a tape of zeros is its own reverse, and arrived that way"
        );
    }

    /// A 16×16 soup of 64-byte tapes, half of them the hand-written reverse copier,
    /// stepped once and sampled.
    fn reverse_colony() -> World {
        let params = Params {
            tape_len: 64,
            mutation_rate: 0.0,
            sample_every: 1,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 5).unwrap();
        let tape = replicator::handwritten_reverse_replicator(64);
        for y in 0..params.height / 2 {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
            }
        }
        world.step();
        world
    }

    /// The head of `handwritten_reverse_replicator` on its filler without the mirrored
    /// tail: a tape whose reverse agrees with it at no position, so a copy of it is as far
    /// from it, byte for byte, as a tape it never touched.
    fn one_way_reverse_copier() -> Vec<u8> {
        const LETTERS: &[u8] = b"abcdefghijklmnopqrstuvwxyz";
        let mut tape: Vec<u8> = (0..64)
            .map(|at| LETTERS[(at * 7) % LETTERS.len()])
            .collect();
        tape[..6].copy_from_slice(b"{[.>{]");
        let reversed: Vec<u8> = tape.iter().rev().copied().collect();
        assert_eq!(metrics::hamming_distance(&tape, &reversed), 64);
        tape
    }

    /// After `epochs` under `rule` of a world whose top half is seeded with
    /// `one_way_reverse_copier` and whose bottom half is random: how many cells carry one
    /// of the colony's tags, and how many hold the colony's reverse copy under a tag that
    /// is not one of them.
    fn reverse_colony_reach(rule: LineageRule, epochs: usize) -> (usize, usize) {
        let params = Params {
            tape_len: 64,
            mutation_rate: 0.0,
            lineage_rule: rule,
            ..soup(16, 16)
        };
        let mut world = World::new(&params, 5).unwrap();
        let tape = one_way_reverse_copier();
        let reversed: Vec<u8> = tape.iter().rev().copied().collect();
        let mut seeded = BTreeSet::new();
        for y in 0..params.height / 2 {
            for x in 0..params.width {
                world.set_cell(x, y, &tape);
                seeded.insert(world.lineage(x, y));
            }
        }
        for _ in 0..epochs {
            world.step();
        }
        let cells = (0..params.height).flat_map(|y| (0..params.width).map(move |x| (x, y)));
        let tagged = cells
            .clone()
            .filter(|(x, y)| seeded.contains(&world.lineage(*x, *y)))
            .count();
        let untagged_copies = cells
            .filter(|(x, y)| {
                world.cell(*x, *y) == reversed && !seeded.contains(&world.lineage(*x, *y))
            })
            .count();
        (tagged, untagged_copies)
    }

    /// A reverse copier invading a random world: its copies are its reverse, which under
    /// the aligned rule is as far from it as from the random tape overwritten, so the
    /// colony's 128 tags never leave home and its copies wear their victims' tags; under
    /// the oriented rule every copy carries the colony's tag out with it.
    #[test]
    fn a_reverse_copier_spreads_its_tags_under_the_oriented_rule_alone() {
        assert_eq!(reverse_colony_reach(LineageRule::Aligned, 10), (128, 12));
        assert_eq!(reverse_colony_reach(LineageRule::Oriented, 10), (140, 0));
    }

    /// The blind spot the companions exist for: a world of tapes that copy in reverse
    /// reads no replicator on the census and next to no `copy_rate`, while the detector
    /// and the reversed rate see them.
    #[test]
    fn a_reverse_copying_colony_reads_on_the_companions_and_not_on_the_census() {
        let measured = reverse_colony().metrics();

        assert_eq!(measured.replicator_count, 0);
        assert_eq!(measured.replicator_pass_rate, Some(0.0));
        assert!(!measured.dominant_replicates);
        assert_eq!(measured.dominant_self_replicates, Some(true));
        let share = measured.replicator_share.expect("a soup");
        assert!(share > 0.4, "{measured:?}");
        assert!(measured.replicator_share_rotated >= Some(share));
        assert!(
            measured.reverse_copy_rate > 0.3 && measured.copy_rate < 0.05,
            "{measured:?}"
        );
    }

    /// The oriented companions over the same colony: its dominant tape is the reverse
    /// copier, whose image is whole at step 4L − 1 and lies reversed, where `copy_cost`
    /// reads nothing because the loop never exits.
    #[test]
    fn a_reverse_copying_colony_reads_a_latency_where_it_reads_no_copy_cost() {
        let measured = reverse_colony().metrics();

        assert_eq!(measured.copy_cost, None);
        assert_eq!(measured.copy_latency, Some(4 * 64 - 1));
        assert_eq!(
            measured.copy_latency_orientation,
            Some(bff::Orientation::Reverse)
        );
        assert!(measured.lineage_variation_oriented <= measured.lineage_variation);
    }

    /// `copy_latency` draws its noise on a stream of its own, apart from every stream the
    /// run, the census and the detector draw on.
    #[test]
    fn the_latency_draws_on_a_stream_no_other_reading_uses() {
        let mut taken: Vec<u64> = vec![
            STREAM_INIT,
            STREAM_STEP,
            STREAM_SELF_REP,
            STREAM_SELF_REP_DOMINANT,
        ];
        taken.extend((0..CENSUS_DRAWS).map(census_stream));
        assert!(!taken.contains(&STREAM_COPY_LATENCY));
    }

    #[test]
    fn a_random_soup_reads_no_self_replicators() {
        let mut world = World::new(&soup(16, 16), 5).unwrap();
        world.step();
        let measured = world.metrics();

        assert_eq!(measured.replicator_share, Some(0.0));
        assert_eq!(measured.replicator_share_rotated, Some(0.0));
        assert_eq!(measured.dominant_self_replicates, Some(false));
    }

    /// The companions only read the world, on streams of their own: sampling every epoch
    /// moves no byte of the run, and a world rebuilt from a snapshot reads what the live
    /// world read at that epoch.
    #[test]
    fn the_companions_move_no_run_and_reread_the_same_from_a_snapshot() {
        let mut sampled = reverse_colony();
        let mut unsampled = reverse_colony();
        let live = sampled.metrics();
        for _ in 0..3 {
            sampled.step();
            sampled.metrics();
            unsampled.step();
        }
        assert_eq!(sampled.world_hash(), unsampled.world_hash());

        let mut world = reverse_colony();
        let mut restored =
            World::from_snapshot(world.params(), world.seed(), &world.snapshot()).unwrap();
        let reread = restored.metrics();
        assert_eq!(reread.replicator_share, live.replicator_share);
        assert_eq!(
            reread.replicator_share_rotated,
            live.replicator_share_rotated
        );
        assert_eq!(
            reread.dominant_self_replicates,
            live.dominant_self_replicates
        );
        assert_eq!(world.metrics(), live);
    }

    #[test]
    fn a_reversed_image_is_read_from_the_first_byte_over_the_sources_length() {
        assert!(reversed_onto(b"cba", b"abc"));
        assert!(
            reversed_onto(b"cbaxx", b"abc"),
            "room past the image does not unmake it"
        );
        assert!(
            !reversed_onto(b"cb", b"abc"),
            "too short to hold the source"
        );
        assert!(!reversed_onto(b"abc", b"abc"));
        assert!(!reversed_onto(b"xcba", b"abc"), "read from the first byte");
    }

    /// A palindrome is its own reverse, so its copy is both images at once.
    #[test]
    fn a_palindromes_copy_counts_in_both_rates() {
        assert!(copied_onto(b"abba", b"abba") && reversed_onto(b"abba", b"abba"));
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
        assert_eq!(world.metrics().reverse_copy_rate, 0.0);
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

    /// A world the way an emerged one looks (#245): most cells the reverse copier, its
    /// loop spread over up to six non-op bytes after each op, at lengths from 40 up to the
    /// cap, over nonzero filler that sometimes holds a steal byte; the rest random.
    fn emerged_world(params: &Params, seed: u64) -> World {
        let mut world = World::new(params, seed).unwrap();
        let mut rng = rng::seeded(seed, 0x454d_4552, 0);
        let cap = params.tape_cap() as u64;
        let filler = |rng: &mut Rng| loop {
            let byte = match rng::below(rng, 32) {
                0 => bff::STEAL,
                _ => 1 + rng::below(rng, 255) as u8,
            };
            if !bff::is_op(byte) {
                return byte;
            }
        };
        for y in 0..params.height {
            for x in 0..params.width {
                let len = 40 + rng::below(&mut rng, cap - 39) as usize;
                let mut tape = Vec::new();
                if rng::below(&mut rng, 5) > 0 {
                    let pad = rng::below(&mut rng, 7);
                    for op in b"{[.<>>{]" {
                        tape.push(*op);
                        tape.extend((0..pad).map(|_| filler(&mut rng)));
                    }
                }
                while tape.len() < len {
                    tape.push(filler(&mut rng));
                }
                tape.truncate(len);
                world.set_cell(x, y, &tape);
            }
        }
        world
    }

    /// Everything a stepped world is and reads: its hash and every piece of its state, and
    /// the whole sample at every tenth epoch.
    fn stepped_both_ways(params: &Params, seed: u64) -> [(Vec<Metrics>, u64, World); 2] {
        [true, false].map(|skipping| {
            bff::SKIPPING.set(skipping);
            let mut world = emerged_world(params, seed);
            let mut samples = Vec::new();
            for _ in 0..5 {
                for _ in 0..10 {
                    world.step();
                }
                samples.push(world.metrics());
            }
            bff::SKIPPING.set(true);
            let hash = world.world_hash();
            (samples, hash, world)
        })
    }

    /// The interpreter's skips are a pure speed-up (`docs/design_record.md`, 2026-09-25):
    /// an emerged world stepped 50 epochs with them and without them ends with the same
    /// hash, tapes, lengths, lineages and stock, and reads the same full sample every tenth
    /// epoch — at the joined default, and under a hosted interaction with the stock and the
    /// steal op on, whose steals the skipped laps count too.
    #[test]
    fn an_emerged_world_steps_exactly_the_same_with_the_skips() {
        let joined = Params {
            tape_len: 64,
            max_tape_len: 128,
            sample_every: 10,
            ..soup(16, 16)
        };
        let economic = Params {
            energy_influx: 6_000,
            energy_stock_cap: 32_768,
            steal_amount: 64,
            interaction: Interaction::Host,
            ..joined.clone()
        };
        for params in [joined, economic] {
            let skipped_before = bff::RECURRED.get() + bff::LAPPED.get();
            let [(skipped_samples, skipped_hash, skipped), (stepped_samples, stepped_hash, stepped)] =
                stepped_both_ways(&params, 11);
            assert!(
                bff::RECURRED.get() + bff::LAPPED.get() - skipped_before > 10_000_000,
                "the copiers never skipped"
            );
            assert_eq!(skipped_hash, stepped_hash);
            assert_eq!(skipped.cells, stepped.cells);
            assert_eq!(skipped.lens, stepped.lens);
            assert_eq!(skipped.lineages, stepped.lineages);
            assert_eq!(skipped.stock, stepped.stock);
            assert_eq!(skipped_samples, stepped_samples);
        }
    }
}
