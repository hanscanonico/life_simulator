//! The observables of `docs/DESIGN.md` §1.2 and the transition tracker built on them.

use crate::bff;
use crate::hash;
use flate2::write::ZlibEncoder;
use flate2::Compression;
use serde::{Deserialize, Serialize};
use std::borrow::Cow;
use std::collections::HashMap;
use std::io::Write;

/// `compress_ratio` below this, held for `TRANSITION_HOLD_SAMPLES` further samples, is
/// what counts as the transition to life.
pub const TRANSITION_THRESHOLD: f64 = 0.6;
pub const TRANSITION_HOLD_SAMPLES: u32 = 3;
/// Above this `op_density`, and below this `alphabet_size`, a compressible world is a
/// collapsed alphabet rather than a colony: with no mutation only `+`/`-` can mint a byte
/// value, so the alphabet is a one-way coalescent that can drift down to a couple of
/// instruction bytes — compressible, all ops, replicating nothing (`docs/DESIGN.md` §1.2).
pub const TRANSITION_MAX_OP_DENSITY: f64 = 0.9;
pub const TRANSITION_MIN_ALPHABET_SIZE: u32 = 16;

/// The companion rule, read against the run's own start instead of the constant above: a
/// fresh soup's `compress_ratio` depends on `max_tape_len` — measured 2026-09-19, the mean
/// over the first `TRANSITION_BASELINE_EPOCHS` epochs falls 0.984 → 0.853 → 0.788 → 0.754
/// as the cap goes 64 → 128 → 256 → 512, so a wide-tape soup starts at the constant
/// threshold and crosses it with nothing replicating. The fraction is that constant
/// expressed against the cap-64 start, 0.6 / 0.984 ≈ 0.61, so the arms the threshold was
/// chosen on read the crossings they always did (`docs/design_record.md`, 2026-09-19).
/// `transition_epoch` stays the locked observable; this is a second reading beside it.
pub const TRANSITION_RELATIVE_FRACTION: f64 = 0.61;
/// The last epoch counted into a run's baseline. A run whose first sample comes later has
/// no baseline, and so no relative reading at all.
pub const TRANSITION_BASELINE_EPOCHS: u64 = 500;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Metrics {
    pub compress_ratio: f64,
    pub distinct_tapes: u64,
    pub top_share: f64,
    pub op_density: f64,
    pub replicator_count: u64,
    pub entropy_bits: f64,
    /// How many of the 256 byte values the world still holds, 1 to 256.
    pub alphabet_size: u32,
    /// Share of the sampled epoch's interactions that ended with one tape byte-exactly
    /// copied over the other half, counting only the pairs that started out different —
    /// replication caught in situ, whoever the partner was.
    pub copy_rate: f64,
    /// How many distinct lineage ids the world's cells hold: descent counted rather than
    /// tape shape, so two lineages that drifted to the same tape still read as two. 0 on
    /// the life substrate, which has no tapes to descend.
    pub distinct_lineages: u64,
    /// Share of cells held by the largest lineage.
    pub top_lineage_share: f64,
    /// Mean bytes by which a cell's tape differs from the modal tape of its lineage,
    /// pooled over the members of the largest lineages that hold more than one cell: 0
    /// for a colony of clones, and climbing as a lineage drifts apart under mutation. 0
    /// on the life substrate.
    pub lineage_variation: f64,
    /// Interpreter steps the dominant replicator needs for one byte-exact copy: the median
    /// over the passing trials of the replicator test, read of the most populous tape among
    /// the `top_k` that passes it. `None` when no tested tape replicates.
    pub copy_cost: Option<u32>,
    /// Bytes of the dominant tape once zlib has had it — its incompressible content, the
    /// open-endedness baseline. The tape is the most populous one among the `top_k` that
    /// passes the replicator test, or the most populous tape of all when none passes, so a
    /// world whose emergence only `copy_rate` confirmed still reads a length. `None` only
    /// where there is no tape to read: the life substrate.
    pub dominant_compressed_len: Option<u32>,
    /// How many of that same tape's bytes the run's instruction set executes.
    pub dominant_instruction_count: Option<u32>,
    /// Whether the tape the two readings above describe passed the replicator test. False
    /// on the life substrate, which has no tapes.
    pub dominant_replicates: bool,
    /// Bytes of that same tape before zlib: what `dominant_compressed_len` is a reading
    /// of, so the two together say how much of the tape is content and how much is length.
    pub dominant_raw_len: Option<u32>,
    /// FNV-1a 64 of that same tape's bytes, as sixteen lowercase hex digits: an identity
    /// for the dominant tape that two samples can be compared on, and nothing else.
    pub dominant_tape_hash: Option<String>,
    /// Byte positions the largest lineage holds invariant: the positions at least
    /// `CONSERVED_CORE_SHARE_NUMERATOR` members in `CONSERVED_CORE_SHARE_DENOMINATOR` give
    /// the same byte value, counted over the largest lineage that holds more than one cell.
    /// `lineage_variation` says how far the cloud has spread; this says how much of it is a
    /// core that survived the spreading. `None` where there is no such lineage, and on the
    /// life substrate.
    pub conserved_core_bytes: Option<u32>,
    /// How many of those conserved positions hold a byte the run's instruction set
    /// executes: the part of the core that is program rather than junk held still.
    pub conserved_core_ops: Option<u32>,
    /// Share of the sampled epoch's interactions in which a steal op executed — theft
    /// caught in situ, whichever half of the pair ran it and whatever it managed to take.
    /// 0 wherever the op is off, which is every run at the defaults, and on the life
    /// substrate.
    pub steal_rate: f64,
    /// Share of the census's independent assay draws in which at least one tape passed the
    /// replicator test. The assay is four Bernoulli trials against random partners, so a
    /// marginal tape passes or fails at random between adjacent epochs and a single draw is
    /// unreadable on its own (`docs/design_record.md`, 2026-09-18). `None` on the life
    /// substrate, which has no tapes to assay.
    pub replicator_pass_rate: Option<f64>,
    /// The mean of those draws' counts: how many cells hold a passing tape on an average
    /// draw, where `replicator_count` is what one draw read. `None` on the life substrate.
    pub replicator_count_mean: Option<f64>,
    /// Bytes of the largest lineage's representative tape once zlib has had it: the same
    /// reading `dominant_compressed_len` makes, of a tape chosen by descent rather than by
    /// population. The dominant tape is whichever tape most cells hold at this sample, and
    /// a lineage that keeps getting more complicated while its modal tape turns over reads
    /// flat through it (`docs/design_record.md`, 2026-09-19). `None` where no lineage holds
    /// two cells, and on the life substrate.
    pub lineage_compressed_len: Option<u32>,
    /// How many of that same representative's bytes the run's instruction set executes.
    pub lineage_instruction_count: Option<u32>,
}

impl Metrics {
    /// Whether this sample counts towards a transition: a compressible world that is not
    /// simply an alphabet that collapsed onto a handful of instruction bytes.
    pub fn transition_candidate(&self) -> bool {
        self.compress_ratio < TRANSITION_THRESHOLD && self.uncollapsed()
    }

    /// The collapse half of the rule on its own, which the relative reading applies too.
    fn uncollapsed(&self) -> bool {
        self.op_density <= TRANSITION_MAX_OP_DENSITY
            && self.alphabet_size >= TRANSITION_MIN_ALPHABET_SIZE
    }
}

/// `zlib(all tapes).len / raw.len` — the BFF paper's headline signal.
pub fn compress_ratio(bytes: &[u8]) -> f64 {
    compress_ratio_of(compress(bytes).len(), bytes.len())
}

/// `compress_ratio` read off a stream `compress` has already produced over the very same
/// bytes — a snapshot's payload, so an epoch that both samples and snapshots compresses
/// once. The compression level and the byte set are part of the observable
/// (`docs/DESIGN.md` §1.2), which is why there is one compressor for both readers.
pub fn compress_ratio_of(compressed_len: usize, raw_len: usize) -> f64 {
    if raw_len == 0 {
        return 0.0;
    }
    compressed_len as f64 / raw_len as f64
}

/// The zlib stream `compress_ratio` measures, and the payload a snapshot carries.
pub fn compress(bytes: &[u8]) -> Vec<u8> {
    let mut encoder = ZlibEncoder::new(Vec::with_capacity(bytes.len() / 4), Compression::default());
    encoder
        .write_all(bytes)
        .expect("writing to a Vec cannot fail");
    encoder.finish().expect("writing to a Vec cannot fail")
}

/// How much tape one replicator is, read two ways, with the length it was read off and
/// the identity of the bytes read (`docs/DESIGN.md` §1.2).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Complexity {
    pub compressed_len: u32,
    pub instruction_count: u32,
    pub raw_len: u32,
    pub tape_hash: u64,
}

impl Complexity {
    /// The length is measured with the very compressor `compress_ratio` uses, so a tape
    /// and the world it sits in are read on one scale. The instructions are counted
    /// against the run's own op set rather than all ten, so an ablated byte the
    /// interpreter skips is not counted as something the tape executes. The hash is the
    /// engine's own FNV-1a 64 over the same bytes — a fixed function of the tape, equal on
    /// every platform and every build, so two samples can be asked whether they read the
    /// same tape.
    pub fn of(tape: &[u8], ops: bff::OpSet) -> Self {
        Self {
            compressed_len: compress(tape).len() as u32,
            instruction_count: tape.iter().filter(|byte| ops.enables(**byte)).count() as u32,
            raw_len: tape.len() as u32,
            tape_hash: hash::fnv1a64(tape),
        }
    }

    /// The hash as the sixteen lowercase hex digits every consumer stores it as: a 64-bit
    /// integer does not survive a JSON reader that parses numbers as doubles, and nothing
    /// downstream does arithmetic on it.
    pub fn tape_hash_hex(&self) -> String {
        format!("{:016x}", self.tape_hash)
    }
}

/// Fraction of bytes that are one of the ten instructions (random bytes ≈ 10/256).
pub fn op_density(bytes: &[u8]) -> f64 {
    if bytes.is_empty() {
        return 0.0;
    }
    let ops = bytes.iter().filter(|b| bff::is_op(**b)).count();
    ops as f64 / bytes.len() as f64
}

/// Shannon entropy of the byte distribution, in bits (8.0 for uniform random bytes).
pub fn entropy_bits(bytes: &[u8]) -> f64 {
    ByteHistogram::of(bytes).entropy_bits()
}

/// How many of the 256 byte values appear at least once (1–256; 0 on an empty buffer).
pub fn alphabet_size(bytes: &[u8]) -> u32 {
    ByteHistogram::of(bytes).alphabet_size()
}

/// The 256 byte counts of a buffer. `op_density`, `entropy_bits` and `alphabet_size` are
/// three readings of the same counts, so a sample of the whole cell buffer builds them
/// once and reads thrice instead of walking a quarter of a megabyte again.
pub struct ByteHistogram {
    bins: [u64; 256],
    total: usize,
}

impl ByteHistogram {
    pub fn of(bytes: &[u8]) -> Self {
        let mut bins = [0u64; 256];
        for byte in bytes {
            bins[*byte as usize] += 1;
        }
        Self {
            bins,
            total: bytes.len(),
        }
    }

    /// The same fraction `op_density` counts byte by byte, summed over the instruction
    /// bins.
    pub fn op_density(&self) -> f64 {
        if self.total == 0 {
            return 0.0;
        }
        let ops: u64 = bff::OPS.iter().map(|op| self.bins[*op as usize]).sum();
        ops as f64 / self.total as f64
    }

    /// The byte values the buffer still holds — the reading that tells a colony from an
    /// alphabet that drifted down to a couple of letters.
    pub fn alphabet_size(&self) -> u32 {
        self.bins.iter().filter(|count| **count > 0).count() as u32
    }

    pub fn entropy_bits(&self) -> f64 {
        if self.total == 0 {
            return 0.0;
        }
        let total = self.total as f64;
        self.bins
            .iter()
            .filter(|count| **count > 0)
            .map(|count| {
                let p = *count as f64 / total;
                -p * p.log2()
            })
            .sum()
    }
}

/// The cells of a world read as tapes. The cells are one flat array of `stride`-wide
/// slots; a world whose tapes can grow (DESIGN §1.3, sweep 8) carries a live length per
/// cell beside it and zeros past each length, and `lens` is what every observable reads
/// through so none of them ever counts the padding. An empty `lens` is a world where
/// every tape fills its slot.
#[derive(Debug, Clone, Copy)]
pub struct Tapes<'a> {
    cells: &'a [u8],
    stride: usize,
    lens: &'a [u32],
}

impl<'a> Tapes<'a> {
    /// A world whose every tape is `stride` bytes long.
    pub fn uniform(cells: &'a [u8], stride: usize) -> Self {
        Self {
            cells,
            stride,
            lens: &[],
        }
    }

    /// A world whose tapes are as long as `lens` says, each inside a `stride`-wide slot.
    pub fn ragged(cells: &'a [u8], stride: usize, lens: &'a [u32]) -> Self {
        Self {
            cells,
            stride,
            lens,
        }
    }

    pub fn stride(&self) -> usize {
        self.stride
    }

    pub fn iter(self) -> impl Iterator<Item = &'a [u8]> {
        let (stride, lens) = (self.stride.max(1), self.lens);
        self.cells
            .chunks_exact(stride)
            .enumerate()
            .map(move |(cell, slot)| match lens.get(cell) {
                Some(len) => &slot[..*len as usize],
                None => slot,
            })
    }

    /// The live bytes end to end — the cells themselves while every tape fills its slot,
    /// so a world that cannot grow is compressed and hashed exactly as it always was.
    pub fn bytes(self) -> Cow<'a, [u8]> {
        if self.lens.is_empty() {
            return Cow::Borrowed(self.cells);
        }
        Cow::Owned(self.iter().flatten().copied().collect())
    }
}

/// Distinct tapes with their populations, ordered by population and ties broken by tape
/// value, so the ranking is a function of the world alone. Sorting the tapes and
/// run-length counting them costs a third of what a map keyed by whole tapes costs on a
/// soup of distinct tapes, and a few microseconds more than it once the soup has
/// converged on a handful. Tapes of different lengths are different tapes.
pub fn ranked_tapes<'a>(tapes: Tapes<'a>) -> Vec<(&'a [u8], u64)> {
    let mut tapes: Vec<&[u8]> = tapes.iter().collect();
    tapes.sort_unstable();

    let mut ranked: Vec<(&[u8], u64)> = Vec::new();
    for tape in tapes {
        match ranked.last_mut() {
            Some((seen, count)) if *seen == tape => *count += 1,
            _ => ranked.push((tape, 1)),
        }
    }
    // A stable sort, so tapes of equal population keep the ascending order above.
    ranked.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
    ranked
}

/// How many distinct lineage ids the cells hold, and the share of cells the largest
/// lineage holds. Counted the way `ranked_tapes` counts tapes — sort, then read the runs.
pub fn lineage_census(lineages: &[u64]) -> (u64, f64) {
    if lineages.is_empty() {
        return (0, 0.0);
    }
    let mut sorted = lineages.to_vec();
    sorted.sort_unstable();

    let mut distinct: u64 = 0;
    let mut top: u64 = 0;
    let mut run: u64 = 0;
    let mut previous: Option<u64> = None;
    for id in sorted {
        if previous == Some(id) {
            run += 1;
        } else {
            distinct += 1;
            run = 1;
            previous = Some(id);
        }
        top = top.max(run);
    }
    (distinct, top as f64 / lineages.len() as f64)
}

/// How many of the largest lineages `lineage_variation` reads. A soup is a crowd of
/// small lineages until a colony spreads through it, and the mean over all of them would
/// read the crowd rather than the colonies; a handful of the largest reads the
/// populations a viewer can actually see.
pub const VARIATION_TOP_LINEAGES: usize = 8;

/// Variation within a lineage: the mean number of bytes by which a cell's tape differs
/// from the modal tape of its lineage — Hamming distance, the same reading the lineage
/// rule makes of descent — pooled over the members of the `VARIATION_TOP_LINEAGES`
/// largest lineages that hold at least two cells. A lineage of one is a cell at distance
/// 0 from itself, so a soup full of them would dilute a drifting colony's reading towards
/// nothing; they are left out, and a world with no lineage of two reads 0. The mean is
/// pooled over the members rather than averaged per lineage, so a lineage counts for as
/// many cells as it holds. 0 for a colony of clones, and it climbs as mutation spreads a
/// lineage over neighbouring tapes.
pub fn lineage_variation(tapes: Tapes<'_>, lineages: &[u64]) -> f64 {
    if lineages.is_empty() || tapes.stride() == 0 {
        return 0.0;
    }
    let tagged = || lineages.iter().copied().zip(tapes.iter());

    let mut read = ranked_lineages(lineages);
    read.truncate(VARIATION_TOP_LINEAGES);
    if read.is_empty() {
        return 0.0;
    }

    let mut members: Vec<(u64, &[u8])> = tagged()
        .filter(|(id, _)| read.iter().any(|(read, _)| read == id))
        .collect();
    // Ordered by lineage then by tape, so each lineage is a contiguous run and the tapes
    // inside it are run-length countable; a tie for the modal tape keeps the lowest tape.
    members.sort_unstable();

    let distance: u64 = members
        .chunk_by(|(one, _), (other, _)| one == other)
        .map(|members| Lineage { members }.distance_to_modal_tape())
        .sum();
    distance as f64 / members.len() as f64
}

/// The lineages that hold more than one cell, largest first and the lowest id of any that
/// tie — the ranking `lineage_variation` and `conserved_core` both read, a function of the
/// world alone however the ids arrived from the map. A lineage of one is left out: it sits
/// at distance 0 from itself and agrees with itself at every byte, so a young soup's crowd
/// of singletons would answer both readings before a colony ever formed.
fn ranked_lineages(lineages: &[u64]) -> Vec<(u64, usize)> {
    let mut sizes: HashMap<u64, usize> = HashMap::new();
    for id in lineages {
        *sizes.entry(*id).or_insert(0) += 1;
    }
    let mut ranked: Vec<(u64, usize)> = sizes.into_iter().filter(|(_, held)| *held > 1).collect();
    ranked.sort_unstable_by_key(|(id, held)| (std::cmp::Reverse(*held), *id));
    ranked
}

/// Share of a lineage's members that must give a byte position the same value for that
/// position to count as conserved: nine in ten (`docs/DESIGN.md` §1.2). It is a ratio of
/// two integers rather than 0.9 so the edge — exactly nine members in ten — is decided by
/// integer arithmetic and not by what a binary float rounds 0.9 to.
pub const CONSERVED_CORE_SHARE_NUMERATOR: u64 = 9;
pub const CONSERVED_CORE_SHARE_DENOMINATOR: u64 = 10;

/// What one lineage holds invariant across its members: the positions they agree on, and
/// how many of those hold an instruction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ConservedCore {
    pub bytes: u32,
    pub ops: u32,
}

/// The conserved core of the largest lineage that holds more than one cell: the byte
/// positions `CONSERVED_CORE_SHARE_NUMERATOR` members in `CONSERVED_CORE_SHARE_DENOMINATOR`
/// give one and the same value, with the count of those positions whose conserved value is
/// an instruction of the run's own op set. `lineage_variation` reads how far the cloud has
/// spread from its modal tape; this reads whether a functional core survived the spreading.
/// A member shorter than a position holds nothing there and so agrees with nobody, the same
/// reading `hamming_distance` makes of a tape that grew. The share is above a half, so at
/// most one byte value per position can carry a position. `None` where no lineage holds two
/// cells, and on a world with no tapes.
pub fn conserved_core(
    tapes: Tapes<'_>,
    lineages: &[u64],
    ops: bff::OpSet,
) -> Option<ConservedCore> {
    let members = largest_lineage_members(tapes, lineages)?;

    let width = members.iter().map(|tape| tape.len()).max().unwrap_or(0);
    // The 256 counts of every position, laid out flat so each member's tape is read in one
    // sequential pass: the whole reading costs members × tape length.
    let mut counts = vec![0u32; width * 256];
    for tape in &members {
        for (position, byte) in tape.iter().enumerate() {
            counts[position * 256 + *byte as usize] += 1;
        }
    }

    let mut core = ConservedCore { bytes: 0, ops: 0 };
    for position in counts.as_chunks::<256>().0 {
        let agreed = position
            .iter()
            .position(|count| conserved(u64::from(*count), members.len() as u64));
        if let Some(byte) = agreed {
            core.bytes += 1;
            core.ops += u32::from(ops.enables(byte as u8));
        }
    }
    Some(core)
}

/// How much tape the largest lineage is, read off one representative of it: the same two
/// readings `Complexity` makes of the dominant tape, taken of a tape chosen by descent.
/// The lineage is the one `conserved_core` and `lineage_variation` already rank — the
/// largest that holds at least two cells, ties by lowest id — and the representative is
/// its modal tape, ties by the lowest tape value, the rule `lineage_variation` already
/// reads a lineage's modal tape by. Both halves are functions of the world alone, so a run
/// resumed from a snapshot reads the same representative the run that wrote it read.
/// `None` where no lineage holds two cells, and on a world with no tapes.
pub fn lineage_complexity(
    tapes: Tapes<'_>,
    lineages: &[u64],
    ops: bff::OpSet,
) -> Option<Complexity> {
    let members = largest_lineage_members(tapes, lineages)?;

    Some(Complexity::of(modal_tape(&members)?, ops))
}

/// The tapes of the lineage `conserved_core` and `lineage_complexity` both read, in cell
/// order: the members of the largest lineage `ranked_lineages` ranks. `None` where no
/// lineage holds two cells, and on a world with no tapes.
fn largest_lineage_members<'a>(tapes: Tapes<'a>, lineages: &[u64]) -> Option<Vec<&'a [u8]>> {
    if lineages.is_empty() || tapes.stride() == 0 {
        return None;
    }
    let (top, _) = *ranked_lineages(lineages).first()?;
    Some(
        lineages
            .iter()
            .copied()
            .zip(tapes.iter())
            .filter(|(id, _)| *id == top)
            .map(|(_, tape)| tape)
            .collect(),
    )
}

/// The most common tape of a lineage's members, and the lowest tape of the ones that tie.
fn modal_tape<'a>(members: &[&'a [u8]]) -> Option<&'a [u8]> {
    let mut sorted = members.to_vec();
    sorted.sort_unstable();

    let mut modal = *sorted.first()?;
    let mut best = 0usize;
    for run in sorted.chunk_by(|one, other| one == other) {
        if run.len() > best {
            best = run.len();
            modal = run[0];
        }
    }
    Some(modal)
}

fn conserved(agreeing: u64, members: u64) -> bool {
    agreeing * CONSERVED_CORE_SHARE_DENOMINATOR >= members * CONSERVED_CORE_SHARE_NUMERATOR
}

/// One lineage's cells, ordered by tape: the grouping `lineage_variation` reads.
struct Lineage<'a> {
    members: &'a [(u64, &'a [u8])],
}

impl Lineage<'_> {
    fn distance_to_modal_tape(&self) -> u64 {
        let modal = self.modal_tape();
        self.members
            .iter()
            .map(|(_, tape)| hamming_distance(tape, modal))
            .sum()
    }

    /// The most common tape of the members, which arrive sorted by tape: the longest run
    /// of equal tapes, and the lowest tape of the runs that tie.
    fn modal_tape(&self) -> &[u8] {
        let mut modal = self.members[0].1;
        let mut best = 0usize;
        for run in self.members.chunk_by(|(_, one), (_, other)| one == other) {
            if run.len() > best {
                best = run.len();
                modal = run[0].1;
            }
        }
        modal
    }
}

/// How many positions two tapes differ in — the reading both the lineage rule and
/// `lineage_variation` make of how far one tape is from another. Tapes of different
/// lengths differ in the bytes they share plus every byte only the longer one has, so a
/// tape that grew has moved away from its lineage by exactly the bytes it gained.
pub(crate) fn hamming_distance(one: &[u8], other: &[u8]) -> u64 {
    let shared = one
        .iter()
        .zip(other)
        .filter(|(left, right)| left != right)
        .count() as u64;
    shared + one.len().abs_diff(other.len()) as u64
}

/// The first sampled epoch at which a qualifying sample appears and holds — the primary
/// dependent variable of every sweep. A sample qualifies on `Metrics::transition_candidate`:
/// `compress_ratio` below the threshold, and neither of the two collapse guards tripped.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct TransitionTracker {
    constant: Hold,
    last_epoch: Option<u64>,
    relative: RelativeTracker,
}

/// The tracker's whole state, so a snapshot can carry it and a resumed run keeps the
/// measurement it had already made — the relative reading's baseline included.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct TransitionState {
    pub candidate: Option<u64>,
    pub held: u32,
    pub settled: Option<u64>,
    pub last_epoch: Option<u64>,
    pub relative: RelativeState,
}

/// The relative reading's state: the baseline as the sum and count it is a mean of, the
/// samples inside the baseline window that cannot be judged until it closes, and the hold
/// machine that judges them.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct RelativeState {
    pub baseline_sum: f64,
    pub baseline_count: u32,
    pub pending: Vec<PendingSample>,
    pub candidate: Option<u64>,
    pub held: u32,
    pub settled: Option<u64>,
}

/// A sample inside the baseline window, kept until the window closes and the baseline it
/// is to be judged against is known.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PendingSample {
    pub epoch: u64,
    pub ratio: f64,
    pub uncollapsed: bool,
}

impl PendingSample {
    fn qualifies(&self, baseline: f64) -> bool {
        self.uncollapsed && self.ratio <= TRANSITION_RELATIVE_FRACTION * baseline
    }
}

/// The candidate-and-hold machine both readings run: a qualifying sample opens a
/// candidate, `TRANSITION_HOLD_SAMPLES` further qualifying samples settle it on the epoch
/// it opened, and one that does not qualify drops it.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
struct Hold {
    candidate: Option<u64>,
    held: u32,
    settled: Option<u64>,
}

impl Hold {
    fn observe(&mut self, epoch: u64, qualifies: bool) {
        if self.settled.is_some() {
            return;
        }
        if !qualifies {
            self.candidate = None;
            self.held = 0;
            return;
        }
        match self.candidate {
            None => {
                self.candidate = Some(epoch);
                self.held = 0;
            }
            Some(candidate) => {
                self.held += 1;
                if self.held >= TRANSITION_HOLD_SAMPLES {
                    self.settled = Some(candidate);
                }
            }
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq)]
struct RelativeTracker {
    baseline_sum: f64,
    baseline_count: u32,
    pending: Vec<PendingSample>,
    hold: Hold,
}

impl RelativeTracker {
    fn from_state(state: RelativeState) -> Self {
        Self {
            baseline_sum: state.baseline_sum,
            baseline_count: state.baseline_count,
            pending: state.pending,
            hold: Hold {
                candidate: state.candidate,
                held: state.held,
                settled: state.settled,
            },
        }
    }

    fn state(&self) -> RelativeState {
        RelativeState {
            baseline_sum: self.baseline_sum,
            baseline_count: self.baseline_count,
            pending: self.pending.clone(),
            candidate: self.hold.candidate,
            held: self.hold.held,
            settled: self.hold.settled,
        }
    }

    fn observe(&mut self, epoch: u64, measured: &Metrics) {
        if self.hold.settled.is_some() {
            return;
        }
        let sample = PendingSample {
            epoch,
            ratio: measured.compress_ratio,
            uncollapsed: measured.uncollapsed(),
        };
        if epoch <= TRANSITION_BASELINE_EPOCHS {
            self.baseline_sum += sample.ratio;
            self.baseline_count += 1;
            self.pending.push(sample);
            return;
        }
        let Some(baseline) = self.baseline() else {
            return;
        };
        for held in std::mem::take(&mut self.pending)
            .into_iter()
            .chain(std::iter::once(sample))
        {
            self.hold.observe(held.epoch, held.qualifies(baseline));
        }
    }

    fn baseline(&self) -> Option<f64> {
        (self.baseline_count > 0).then(|| self.baseline_sum / f64::from(self.baseline_count))
    }
}

impl TransitionTracker {
    pub fn from_state(state: TransitionState) -> Self {
        Self {
            constant: Hold {
                candidate: state.candidate,
                held: state.held,
                settled: state.settled,
            },
            last_epoch: state.last_epoch,
            relative: RelativeTracker::from_state(state.relative),
        }
    }

    pub fn state(&self) -> TransitionState {
        TransitionState {
            candidate: self.constant.candidate,
            held: self.constant.held,
            settled: self.constant.settled,
            last_epoch: self.last_epoch,
            relative: self.relative.state(),
        }
    }

    pub fn observe(&mut self, epoch: u64, measured: &Metrics) {
        if self.last_epoch == Some(epoch) {
            return;
        }
        self.last_epoch = Some(epoch);
        self.constant
            .observe(epoch, measured.transition_candidate());
        self.relative.observe(epoch, measured);
    }

    pub fn epoch(&self) -> Option<u64> {
        self.constant.settled
    }

    /// The same measurement made against the run's own baseline rather than the constant
    /// threshold. Locked nothing: `epoch` above is the observable every finding reads.
    pub fn relative_epoch(&self) -> Option<u64> {
        self.relative.hold.settled
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compress_ratio_separates_noise_from_repetition() {
        let repeated = vec![b'x'; 4096];
        assert!(compress_ratio(&repeated) < 0.1);

        let mut rng = crate::rng::seeded(1, 0, 0);
        let noise: Vec<u8> = (0..4096).map(|_| crate::rng::byte(&mut rng)).collect();
        assert!(compress_ratio(&noise) > 0.9);
    }

    #[test]
    fn op_density_counts_only_instruction_bytes() {
        assert_eq!(op_density(b"+-<>{}.,[]"), 1.0);
        assert_eq!(op_density(b"aaaa"), 0.0);
        assert_eq!(op_density(b"a+a+"), 0.5);
    }

    #[test]
    fn entropy_is_zero_for_one_byte_value_and_eight_bits_for_all_of_them() {
        assert_eq!(entropy_bits(&[7; 32]), 0.0);
        let all: Vec<u8> = (0..=255).collect();
        assert!((entropy_bits(&all) - 8.0).abs() < 1e-9);
        assert_eq!(entropy_bits(&[]), 0.0);
    }

    #[test]
    fn a_clonal_lineage_varies_by_nothing_and_a_drifted_one_by_its_drift() {
        let stride = 4;
        assert_eq!(lineage_variation(Tapes::uniform(b"", stride), &[]), 0.0);
        assert_eq!(
            lineage_variation(Tapes::uniform(b"abcdabcdabcd", stride), &[1, 1, 1]),
            0.0
        );
        // Two members on the modal tape, one a byte away: one differing byte over three
        // members.
        assert_eq!(
            lineage_variation(Tapes::uniform(b"abcdabcdabce", stride), &[1, 1, 1]),
            1.0 / 3.0
        );
        // Two tapes, neither more common than the other and every byte apart: whichever
        // of them is modal, the other reads the whole tape.
        assert_eq!(
            lineage_variation(Tapes::uniform(b"abcdwxyz", stride), &[1, 1]),
            2.0
        );
    }

    #[test]
    fn the_modal_tape_is_the_most_common_one_and_the_lowest_of_any_that_tie() {
        // Two members on "bb" and one on "aa": the modal tape is the one most members
        // hold, not the lowest one they hold, so this reads 2 bytes over 3 members and
        // not the 4 it would read from "aa".
        assert_eq!(
            lineage_variation(Tapes::uniform(b"bbbbaa", 2), &[1, 1, 1]),
            2.0 / 3.0
        );
        // Three tapes, none more common than another: the lowest breaks the tie, so the
        // distances are measured from "aa" and not from "bc", which would read 1.0.
        assert_eq!(
            lineage_variation(Tapes::uniform(b"aabbbc", 2), &[1, 1, 1]),
            4.0 / 3.0
        );
    }

    #[test]
    fn lineage_variation_weighs_every_lineage_it_reads_by_population() {
        // Lineage 1 holds four cells two of which are on its modal tape, lineage 2 two
        // clones: four differing bytes over six members, and not the 0.5 a mean of the
        // two lineages' own means would read.
        assert_eq!(
            lineage_variation(Tapes::uniform(b"aaaabbccdddd", 2), &[1, 1, 1, 1, 2, 2]),
            2.0 / 3.0
        );
    }

    #[test]
    fn a_lineage_of_one_cell_is_no_lineage_to_read() {
        // A cell alone in its lineage is a clone of itself at distance 0, so reading the
        // singletons would dilute the drifting lineage below towards nothing.
        assert_eq!(
            lineage_variation(Tapes::uniform(b"aabbcc", 2), &[1, 2, 3]),
            0.0
        );
        // Lineage 1 drifted by two bytes over two cells; the six singletons around it do
        // not pull its reading down.
        assert_eq!(
            lineage_variation(Tapes::uniform(b"aabbccddeeffgg", 2), &[1, 1, 2, 3, 4, 5, 6]),
            1.0
        );
    }

    /// On a world whose tapes can grow, a lineage's members need not be the same length:
    /// the distance to the modal tape counts the bytes only one of them has.
    #[test]
    fn lineage_variation_counts_the_bytes_a_grown_tape_gained() {
        let cells = b"abcd\0\0abcd\0\0abcdef";
        let lens = [4u32, 4, 6];
        assert_eq!(
            lineage_variation(Tapes::ragged(cells, 6, &lens), &[1, 1, 1]),
            2.0 / 3.0,
            "the modal tape is the short one two cells hold"
        );
        assert_eq!(
            ranked_tapes(Tapes::ragged(cells, 6, &lens)),
            vec![(&b"abcd"[..], 2), (&b"abcdef"[..], 1)]
        );
    }

    #[test]
    fn a_lineage_of_clones_conserves_every_byte_of_its_tape() {
        let core = conserved_core(
            Tapes::uniform(b"+a[b+a[b+a[b", 4),
            &[1, 1, 1],
            bff::OpSet::ALL,
        )
        .expect("a lineage of three");
        assert_eq!(core.bytes, 4, "every position agrees");
        assert_eq!(core.ops, 2, "two of the four bytes are instructions");
    }

    #[test]
    fn a_position_is_conserved_at_nine_members_in_ten_and_not_at_eight() {
        let mut cells = b"ab".repeat(9);
        cells.extend_from_slice(b"az");
        let ten = [1u64; 10];
        assert_eq!(
            conserved_core(Tapes::uniform(&cells, 2), &ten, bff::OpSet::ALL)
                .expect("a lineage of ten")
                .bytes,
            2,
            "exactly nine members in ten agreeing is the threshold, not past it"
        );

        let mut cells = b"ab".repeat(8);
        cells.extend_from_slice(b"azay");
        assert_eq!(
            conserved_core(Tapes::uniform(&cells, 2), &ten, bff::OpSet::ALL)
                .expect("a lineage of ten")
                .bytes,
            1,
            "a position two members in ten dissent on is out of the core"
        );
    }

    #[test]
    fn conserved_ops_are_counted_against_the_run_own_instruction_set() {
        let ablated = bff::OpSet::parse("<>{}+-.,[").expect("a legal set");
        let cells = b"+]+]+]";
        assert_eq!(
            conserved_core(Tapes::uniform(cells, 2), &[1, 1, 1], bff::OpSet::ALL)
                .expect("a lineage of three")
                .ops,
            2
        );
        assert_eq!(
            conserved_core(Tapes::uniform(cells, 2), &[1, 1, 1], ablated)
                .expect("a lineage of three")
                .ops,
            1,
            "the byte whose op the run ablated is not an instruction the tape executes"
        );
    }

    #[test]
    fn a_member_too_short_to_reach_a_position_agrees_with_nobody_there() {
        let cells = b"abcd\0\0abcd\0\0abcdef";
        let lens = [4u32, 4, 6];
        let core = conserved_core(Tapes::ragged(cells, 6, &lens), &[1, 1, 1], bff::OpSet::ALL)
            .expect("a lineage of three");
        assert_eq!(
            core.bytes, 4,
            "the two bytes only the grown tape holds are held by one member in three"
        );
    }

    #[test]
    fn the_conserved_core_reads_the_largest_lineage_alone() {
        let cells = b"abababzz";
        assert_eq!(
            conserved_core(Tapes::uniform(cells, 2), &[1, 1, 1, 2], bff::OpSet::ALL)
                .expect("a lineage of three")
                .bytes,
            2,
            "the singleton second lineage is not what is read"
        );

        // `ab ab ab` under lineage 1 and `cd ce` under lineage 2: the second is ranked as
        // well, holding two cells, and its core is one byte rather than two.
        let cells = b"abababcdce";
        assert_eq!(
            conserved_core(Tapes::uniform(cells, 2), &[1, 1, 1, 2, 2], bff::OpSet::ALL)
                .expect("a lineage of three")
                .bytes,
            2,
            "the smaller lineage of two is not what is read either"
        );

        let cells = b"aaabacbbbb";
        assert_eq!(
            conserved_core(Tapes::uniform(cells, 5), &[1, 2], bff::OpSet::ALL),
            None,
            "no lineage holds two cells"
        );
        assert_eq!(
            conserved_core(Tapes::uniform(b"", 0), &[], bff::OpSet::ALL),
            None
        );
    }

    #[test]
    fn the_lineage_complexity_reads_the_modal_tape_of_the_largest_lineage() {
        // `+[ +[ +a` under lineage 1 and `zz zz` under lineage 2: the larger lineage's
        // modal tape is `+[`, whichever tape the world holds most of.
        let cells = b"+[+[+azzzz";
        let read = lineage_complexity(Tapes::uniform(cells, 2), &[1, 1, 1, 2, 2], bff::OpSet::ALL)
            .expect("a lineage of three");

        assert_eq!(read.tape_hash, hash::fnv1a64(b"+["));
        assert_eq!(read.instruction_count, 2);
        assert_eq!(read.raw_len, 2);
    }

    #[test]
    fn a_tie_for_the_modal_tape_keeps_the_lowest_tape() {
        for cells in [b"+[ab", b"ab+["] {
            let read = lineage_complexity(Tapes::uniform(cells, 2), &[1, 1], bff::OpSet::ALL)
                .expect("a lineage of two");

            assert_eq!(
                read.tape_hash,
                hash::fnv1a64(b"+["),
                "`+[` sorts below `ab`, whichever cell holds it"
            );
        }
    }

    #[test]
    fn a_world_with_no_lineage_of_two_reads_no_lineage_complexity() {
        assert_eq!(
            lineage_complexity(Tapes::uniform(b"aaabacbbbb", 5), &[1, 2], bff::OpSet::ALL),
            None
        );
        assert_eq!(
            lineage_complexity(Tapes::uniform(b"", 0), &[], bff::OpSet::ALL),
            None
        );
    }

    #[test]
    fn a_lineage_that_drifted_apart_keeps_only_the_bytes_it_held_still() {
        let mut cells: Vec<u8> = Vec::new();
        for member in 0..10u8 {
            cells.extend_from_slice(&[b'+', b'a' + member, b'[']);
        }
        let core = conserved_core(Tapes::uniform(&cells, 3), &[1u64; 10], bff::OpSet::ALL)
            .expect("a lineage of ten");
        assert_eq!(core.bytes, 2, "the drifting middle byte is out of the core");
        assert_eq!(core.ops, 2, "and both survivors are instructions");
    }

    #[test]
    fn lineage_variation_reads_only_the_largest_lineages() {
        let pairs = VARIATION_TOP_LINEAGES as u64;
        let mut cells: Vec<u8> = Vec::new();
        let mut lineages: Vec<u64> = Vec::new();
        for id in 1..=pairs {
            cells.extend_from_slice(&[b'a' + id as u8, b'z', b'a' + id as u8, b'z']);
            lineages.extend_from_slice(&[id, id]);
        }
        // The one lineage that drifted is the largest and holds the highest id, so a
        // reading that took the first eight lineages rather than the largest would miss
        // it and report 0.
        let largest = pairs + 1;
        cells.extend_from_slice(b"aaaabb");
        lineages.extend_from_slice(&[largest, largest, largest]);

        // The drifted three and seven of the eight clone pairs, the eighth cut by the
        // top-eight rule: two differing bytes over seventeen members, not nineteen.
        assert_eq!(
            lineage_variation(Tapes::uniform(&cells, 2), &lineages),
            2.0 / 17.0
        );
    }

    /// The definition of `docs/DESIGN.md` §1.2 written out without the counting pass the
    /// reading uses to keep the sort off every cell: every lineage grouped in a map, the
    /// ones holding more than a cell ranked, the modal tape counted tape by tape.
    fn variation_the_long_way(cells: &[u8], stride: usize, lineages: &[u64]) -> f64 {
        let mut grouped: std::collections::BTreeMap<u64, Vec<&[u8]>> =
            std::collections::BTreeMap::new();
        for (id, tape) in lineages.iter().copied().zip(cells.chunks_exact(stride)) {
            grouped.entry(id).or_default().push(tape);
        }
        let mut ranked: Vec<(u64, Vec<&[u8]>)> = grouped
            .into_iter()
            .filter(|(_, members)| members.len() > 1)
            .collect();
        ranked.sort_by_key(|(id, members)| (std::cmp::Reverse(members.len()), *id));

        let mut distance = 0u64;
        let mut counted = 0usize;
        for (_, members) in ranked.into_iter().take(VARIATION_TOP_LINEAGES) {
            let modal = members
                .iter()
                .min_by_key(|tape| {
                    let held = members.iter().filter(|other| other == tape).count();
                    (std::cmp::Reverse(held), **tape)
                })
                .expect("a ranked lineage holds members");
            distance += members
                .iter()
                .map(|tape| hamming_distance(tape, modal))
                .sum::<u64>();
            counted += members.len();
        }
        if counted == 0 {
            return 0.0;
        }
        distance as f64 / counted as f64
    }

    #[test]
    fn the_variation_matches_the_definition_written_out_the_long_way() {
        let mut rng = crate::rng::seeded(11, 0, 0);
        for lineage_count in [1u64, 3, 8, 9, 40] {
            let cells: Vec<u8> = (0..8 * 200)
                .map(|_| b'a' + (crate::rng::byte(&mut rng) % 3))
                .collect();
            let lineages: Vec<u64> = (0..200)
                .map(|_| crate::rng::byte(&mut rng) as u64 % lineage_count)
                .collect();
            assert_eq!(
                lineage_variation(Tapes::uniform(&cells, 8), &lineages),
                variation_the_long_way(&cells, 8, &lineages),
                "{lineage_count} lineages"
            );
        }
    }

    /// The hand-written copier is 16 bytes of program — one of them the zero counter, the
    /// other fifteen instructions — in front of 240 bytes of filler, and zlib squeezes
    /// that run of filler down to nothing much. Both readings are pinned here: they are
    /// the yardstick every later substrate's complexity is read against.
    #[test]
    fn the_handwritten_replicators_complexity_is_known() {
        let read = Complexity::of(
            &crate::replicator::handwritten_replicator(),
            bff::OpSet::ALL,
        );
        assert_eq!(read.compressed_len, 36);
        assert_eq!(read.instruction_count, 15);
    }

    /// The raw length and the hash are of the very bytes the other two readings are taken
    /// off, so a compressed length can be read as a fraction of a tape rather than as a
    /// number that saturates at the cap.
    #[test]
    fn the_dominant_tape_is_measured_and_identified_by_its_own_bytes() {
        let tape = crate::replicator::handwritten_replicator();
        let read = Complexity::of(&tape, bff::OpSet::ALL);
        assert_eq!(read.raw_len, tape.len() as u32);
        assert_eq!(read.tape_hash, hash::fnv1a64(&tape));
        assert_eq!(read.tape_hash_hex().len(), 16);
        assert_eq!(read.tape_hash_hex(), format!("{:016x}", read.tape_hash));
    }

    #[test]
    fn a_tape_that_changed_by_one_byte_is_a_different_tape() {
        let tape = crate::replicator::handwritten_replicator();
        let mut moved = tape.clone();
        moved[3] = moved[3].wrapping_add(1);
        assert_ne!(
            Complexity::of(&tape, bff::OpSet::ALL).tape_hash,
            Complexity::of(&moved, bff::OpSet::ALL).tape_hash
        );
    }

    /// The op set decides what counts as an instruction and nothing else: the bytes are
    /// the bytes whatever runs them.
    #[test]
    fn the_op_set_moves_neither_the_raw_length_nor_the_hash() {
        let tape = crate::replicator::handwritten_replicator();
        let ablated = bff::OpSet::parse("<>{}+-,[]").expect("a legal set");
        assert_eq!(
            (
                Complexity::of(&tape, ablated).raw_len,
                Complexity::of(&tape, ablated).tape_hash
            ),
            (
                Complexity::of(&tape, bff::OpSet::ALL).raw_len,
                Complexity::of(&tape, bff::OpSet::ALL).tape_hash
            )
        );
    }

    #[test]
    fn an_ablated_op_is_not_an_instruction_the_tape_executes() {
        let tape = crate::replicator::handwritten_replicator();
        let without_copy_to_head1 = bff::OpSet::parse("<>{}+-,[]").expect("a legal set");
        assert_eq!(
            Complexity::of(&tape, without_copy_to_head1).instruction_count,
            13,
            "the tape's two `.` bytes are dead under this set"
        );
        assert_eq!(
            Complexity::of(&tape, without_copy_to_head1).compressed_len,
            Complexity::of(&tape, bff::OpSet::ALL).compressed_len,
            "the bytes are the same bytes whatever runs them"
        );
    }

    #[test]
    fn a_random_tape_barely_compresses_and_holds_the_odd_instruction() {
        let mut rng = crate::rng::seeded(3, 0, 0);
        let tape: Vec<u8> = (0..256).map(|_| crate::rng::byte(&mut rng)).collect();
        let read = Complexity::of(&tape, bff::OpSet::ALL);
        assert!(read.compressed_len > 256, "{read:?}");
        assert_eq!(
            f64::from(read.instruction_count) / tape.len() as f64,
            op_density(&tape),
            "with every op enabled the count is the density over the tape"
        );
        assert!(read.instruction_count < 32, "{read:?}");
    }

    #[test]
    fn the_lineage_census_counts_ids_and_the_largest_share() {
        assert_eq!(lineage_census(&[]), (0, 0.0));
        assert_eq!(lineage_census(&[7, 7, 7, 7]), (1, 1.0));
        assert_eq!(lineage_census(&[0, 1, 2, 3]), (4, 0.25));
        assert_eq!(lineage_census(&[5, 9, 5, 2]), (3, 0.5));
    }

    #[test]
    fn tapes_are_counted_and_ranked_by_population() {
        let cells = [1, 1, 2, 2, 1, 1, 3, 3, 1, 1];
        let ranked = ranked_tapes(Tapes::uniform(&cells, 2));
        assert_eq!(ranked.len(), 3);
        assert_eq!(ranked[0], (&[1u8, 1][..], 3));
        assert_eq!(ranked[1], (&[2u8, 2][..], 1), "ties break by tape value");
        assert_eq!(ranked[2], (&[3u8, 3][..], 1));
    }

    /// The ranking a `BTreeMap` keyed by whole tapes produced, which every recorded
    /// `distinct_tapes`, `top_share` and `replicator_count` was read from.
    fn ranked_through_a_map(cells: &[u8], stride: usize) -> Vec<(&[u8], u64)> {
        let mut counts: std::collections::BTreeMap<&[u8], u64> = std::collections::BTreeMap::new();
        for tape in cells.chunks_exact(stride) {
            *counts.entry(tape).or_insert(0) += 1;
        }
        let mut ranked: Vec<(&[u8], u64)> = counts.iter().map(|(tape, n)| (*tape, *n)).collect();
        ranked.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
        ranked
    }

    #[test]
    fn the_ranking_matches_the_map_it_replaces_on_a_random_soup() {
        let mut rng = crate::rng::seeded(7, 0, 0);
        let cells: Vec<u8> = (0..64 * 512).map(|_| crate::rng::byte(&mut rng)).collect();
        assert_eq!(
            ranked_tapes(Tapes::uniform(&cells, 64)),
            ranked_through_a_map(&cells, 64)
        );
    }

    #[test]
    fn the_ranking_matches_the_map_it_replaces_on_a_soup_full_of_ties() {
        let mut rng = crate::rng::seeded(8, 0, 0);
        let distinct: Vec<u8> = (0..64 * 8).map(|_| crate::rng::byte(&mut rng)).collect();
        let mut cells = Vec::new();
        for cell in 0..512usize {
            let tape = cell % 8;
            cells.extend_from_slice(&distinct[tape * 64..tape * 64 + 64]);
        }
        let ranked = ranked_tapes(Tapes::uniform(&cells, 64));
        assert_eq!(
            ranked.len(),
            8,
            "every tape shares its count with the others"
        );
        assert_eq!(ranked, ranked_through_a_map(&cells, 64));
    }

    /// The entropy `entropy_bits` summed from a histogram of its own, which every
    /// recorded `entropy_bits` was read from — bin order included, so the floating-point
    /// sum is the same one.
    fn entropy_through_its_own_pass(bytes: &[u8]) -> f64 {
        if bytes.is_empty() {
            return 0.0;
        }
        let mut histogram = [0u64; 256];
        for byte in bytes {
            histogram[*byte as usize] += 1;
        }
        let total = bytes.len() as f64;
        histogram
            .iter()
            .filter(|count| **count > 0)
            .map(|count| {
                let p = *count as f64 / total;
                -p * p.log2()
            })
            .sum()
    }

    #[test]
    fn the_histogram_reads_the_same_op_density_and_entropy_as_a_pass_each() {
        let mut rng = crate::rng::seeded(9, 0, 0);
        let bytes: Vec<u8> = (0..4096).map(|_| crate::rng::byte(&mut rng)).collect();
        let histogram = ByteHistogram::of(&bytes);
        assert_eq!(histogram.op_density(), op_density(&bytes));
        assert_eq!(
            histogram.entropy_bits(),
            entropy_through_its_own_pass(&bytes)
        );

        let empty = ByteHistogram::of(&[]);
        assert_eq!(empty.op_density(), 0.0);
        assert_eq!(empty.entropy_bits(), 0.0);
    }

    #[test]
    fn a_snapshots_payload_length_reads_the_same_compress_ratio() {
        let mut rng = crate::rng::seeded(10, 0, 0);
        let cells: Vec<u8> = (0..4096).map(|_| crate::rng::byte(&mut rng)).collect();
        let payload = compress(&cells);
        let encoded = crate::snapshot::encode_compressed(
            &crate::snapshot::Header {
                substrate: crate::params::Substrate::Soup,
                width: 8,
                height: 8,
                tape_len: 64,
                tape_cap: 64,
                epoch: 0,
                transition: TransitionState::default(),
            },
            &payload,
            &[],
            &[],
            &[],
        );
        assert_eq!(
            &encoded[crate::snapshot::HEADER_LEN_RELATIVE
                ..crate::snapshot::HEADER_LEN_RELATIVE + payload.len()],
            &payload[..]
        );
        assert_eq!(
            compress_ratio_of(payload.len(), cells.len()),
            compress_ratio(&cells)
        );
        assert_eq!(compress_ratio_of(0, 0), 0.0);
        assert_eq!(compress_ratio(&[]), 0.0);
    }

    /// A sample of a compressible world with a live alphabet, the reading the tracker
    /// counts: only `compress_ratio` moves from test to test.
    fn reading(compress_ratio: f64) -> Metrics {
        Metrics {
            compress_ratio,
            distinct_tapes: 128,
            top_share: 0.1,
            op_density: 0.2,
            replicator_count: 0,
            entropy_bits: 5.0,
            alphabet_size: 256,
            copy_rate: 0.0,
            distinct_lineages: 128,
            top_lineage_share: 0.1,
            lineage_variation: 0.0,
            copy_cost: None,
            dominant_compressed_len: None,
            dominant_instruction_count: None,
            dominant_replicates: false,
            dominant_raw_len: None,
            dominant_tape_hash: None,
            conserved_core_bytes: None,
            conserved_core_ops: None,
            steal_rate: 0.0,
            replicator_pass_rate: None,
            replicator_count_mean: None,
            lineage_compressed_len: None,
            lineage_instruction_count: None,
        }
    }

    #[test]
    fn transition_settles_on_the_first_epoch_of_a_sustained_drop() {
        let mut tracker = TransitionTracker::default();
        tracker.observe(10, &reading(0.9));
        tracker.observe(20, &reading(0.5));
        tracker.observe(30, &reading(0.9));
        assert_eq!(tracker.epoch(), None, "the drop did not hold");

        tracker.observe(40, &reading(0.5));
        tracker.observe(50, &reading(0.4));
        tracker.observe(60, &reading(0.4));
        assert_eq!(tracker.epoch(), None, "only two further samples so far");
        tracker.observe(70, &reading(0.3));
        assert_eq!(tracker.epoch(), Some(40));

        tracker.observe(80, &reading(0.99));
        assert_eq!(tracker.epoch(), Some(40), "settled epochs never move");
    }

    /// The shape of production run 41's series, sampled every ten epochs: noise for 500
    /// samples, then a fall that holds low for the rest of the run.
    #[test]
    fn the_detector_reports_the_first_sample_below_the_threshold_across_a_resume() {
        let mut tracker = TransitionTracker::default();
        for sample in 0..500u64 {
            tracker.observe(sample * 10, &reading(0.94));
        }
        tracker.observe(5000, &reading(0.725));
        tracker.observe(5010, &reading(0.526));
        tracker.observe(5020, &reading(0.052));
        assert_eq!(tracker.epoch(), None, "the drop has not held yet");

        let mut resumed = TransitionTracker::from_state(tracker.state());
        for sample in 1..=1500u64 {
            resumed.observe(5020 + sample * 10, &reading(0.05));
        }
        assert_eq!(resumed.epoch(), Some(5010));
    }

    #[test]
    fn a_collapsed_alphabet_never_settles_however_compressible_it_reads() {
        let collapsed = Metrics {
            op_density: 1.0,
            alphabet_size: 2,
            ..reading(0.143)
        };
        let mut tracker = TransitionTracker::default();
        for sample in 0..100u64 {
            tracker.observe(sample * 10, &collapsed);
        }
        assert_eq!(tracker.epoch(), None, "run 183's shape is not a transition");
    }

    #[test]
    fn each_guard_disqualifies_a_sample_on_its_own() {
        assert!(reading(0.5).transition_candidate());
        assert!(!reading(0.6).transition_candidate());
        assert!(!Metrics {
            op_density: 0.91,
            ..reading(0.5)
        }
        .transition_candidate());
        assert!(Metrics {
            op_density: 0.9,
            ..reading(0.5)
        }
        .transition_candidate());
        assert!(!Metrics {
            alphabet_size: 15,
            ..reading(0.5)
        }
        .transition_candidate());
        assert!(Metrics {
            alphabet_size: 16,
            ..reading(0.5)
        }
        .transition_candidate());
    }

    #[test]
    fn the_alphabet_counts_the_byte_values_present() {
        assert_eq!(alphabet_size(&[7; 32]), 1);
        assert_eq!(alphabet_size(b"{.{.{."), 2);
        let all: Vec<u8> = (0..=255).collect();
        assert_eq!(alphabet_size(&all), 256);
        assert_eq!(alphabet_size(&[]), 0);
    }

    /// A tape cap wide enough to start near the constant threshold: the run slips under
    /// 0.6 and the constant rule flags it, while against its own start of 0.62 it has
    /// barely moved and the relative rule reads nothing.
    #[test]
    fn a_run_that_starts_at_the_threshold_flags_on_the_constant_rule_alone() {
        let mut tracker = TransitionTracker::default();
        for sample in 0..=50u64 {
            tracker.observe(sample * 10, &reading(0.62));
        }
        for sample in 51..200u64 {
            tracker.observe(sample * 10, &reading(0.58));
        }

        assert_eq!(tracker.epoch(), Some(510));
        assert_eq!(
            tracker.relative_epoch(),
            None,
            "0.58 is 94% of its baseline"
        );
    }

    /// A run that starts where the threshold was chosen — cap 64, mean 0.984 — and falls
    /// to 0.55 crosses both rules, on the same epoch: that is what
    /// `TRANSITION_RELATIVE_FRACTION` is derived to do.
    #[test]
    fn a_run_that_starts_high_and_falls_reads_the_same_epoch_on_both_rules() {
        let mut tracker = TransitionTracker::default();
        for sample in 0..=50u64 {
            tracker.observe(sample * 10, &reading(0.98));
        }
        for sample in 51..200u64 {
            tracker.observe(sample * 10, &reading(0.55));
        }

        assert_eq!(tracker.epoch(), Some(510));
        assert_eq!(tracker.relative_epoch(), Some(510));
    }

    /// The baseline is the run's own start, so a crossing inside the baseline window is
    /// judged once the window closes rather than against a mean of a handful of samples.
    #[test]
    fn a_crossing_inside_the_baseline_window_is_read_once_the_window_closes() {
        let mut tracker = TransitionTracker::default();
        tracker.observe(0, &reading(0.98));
        tracker.observe(100, &reading(0.98));
        for sample in 2..=5u64 {
            tracker.observe(sample * 100, &reading(0.2));
        }
        assert_eq!(
            tracker.relative_epoch(),
            None,
            "the window has not closed yet"
        );

        tracker.observe(600, &reading(0.2));
        assert_eq!(tracker.relative_epoch(), Some(200));
    }

    /// A run whose first sample comes after the window has no baseline to be read
    /// against, and so no relative reading at all.
    #[test]
    fn a_run_with_no_sample_inside_the_baseline_window_reads_no_relative_epoch() {
        let mut tracker = TransitionTracker::default();
        for sample in 0..20u64 {
            tracker.observe(600 + sample * 10, &reading(0.05));
        }

        assert_eq!(tracker.epoch(), Some(600));
        assert_eq!(tracker.relative_epoch(), None);
    }

    /// The relative reading is measured against the run's own start, so a run snapshotted
    /// inside its baseline window and resumed has to read the epoch the uninterrupted run
    /// reads — baseline, pending samples and all.
    #[test]
    fn a_resumed_tracker_reads_the_relative_epoch_the_uninterrupted_one_reads() {
        let params = crate::params::Params {
            width: 8,
            height: 4,
            tape_len: 16,
            ..crate::params::Params::default()
        };
        let cells = vec![0u8; params.cell_count() * params.stride()];
        let series: Vec<(u64, f64)> = (0..=50)
            .map(|sample| (sample * 10, 0.98))
            .chain((51..200).map(|sample| (sample * 10, 0.55)))
            .collect();

        let mut uninterrupted = TransitionTracker::default();
        for (epoch, ratio) in &series {
            uninterrupted.observe(*epoch, &reading(*ratio));
        }

        let mut resumed = TransitionTracker::default();
        for (epoch, ratio) in &series[..20] {
            resumed.observe(*epoch, &reading(*ratio));
        }
        let bytes = crate::snapshot::encode(
            &crate::snapshot::Header {
                substrate: params.substrate,
                width: params.width,
                height: params.height,
                tape_len: params.tape_len,
                tape_cap: params.tape_cap(),
                epoch: 190,
                transition: resumed.state(),
            },
            &cells,
            &vec![0u64; params.lineage_count()],
            &[],
            &[],
        );
        let restored = crate::snapshot::decode(&params, &bytes).unwrap();
        let mut resumed = TransitionTracker::from_state(restored.header.transition);
        for (epoch, ratio) in &series[20..] {
            resumed.observe(*epoch, &reading(*ratio));
        }

        assert_eq!(uninterrupted.relative_epoch(), Some(510));
        assert_eq!(resumed.relative_epoch(), uninterrupted.relative_epoch());
        assert_eq!(resumed.epoch(), uninterrupted.epoch());
    }

    #[test]
    fn repeated_samples_of_one_epoch_count_once() {
        let mut tracker = TransitionTracker::default();
        for _ in 0..10 {
            tracker.observe(5, &reading(0.1));
        }
        assert_eq!(tracker.epoch(), None);
    }
}
