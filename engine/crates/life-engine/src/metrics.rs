//! The observables of `docs/DESIGN.md` §1.2 and the transition tracker built on them.

use crate::bff;
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
    /// Bytes of the dominant replicator's tape once zlib has had it — its incompressible
    /// content, the open-endedness baseline. `None` when no tested tape replicates.
    pub dominant_compressed_len: Option<u32>,
    /// How many of the dominant replicator's bytes the run's instruction set executes.
    /// `None` when no tested tape replicates.
    pub dominant_instruction_count: Option<u32>,
}

impl Metrics {
    /// Whether this sample counts towards a transition: a compressible world that is not
    /// simply an alphabet that collapsed onto a handful of instruction bytes.
    pub fn transition_candidate(&self) -> bool {
        self.compress_ratio < TRANSITION_THRESHOLD
            && self.op_density <= TRANSITION_MAX_OP_DENSITY
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

/// How much tape one replicator is, read two ways (`docs/DESIGN.md` §1.2).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Complexity {
    pub compressed_len: u32,
    pub instruction_count: u32,
}

impl Complexity {
    /// The length is measured with the very compressor `compress_ratio` uses, so a tape
    /// and the world it sits in are read on one scale. The instructions are counted
    /// against the run's own op set rather than all ten, so an ablated byte the
    /// interpreter skips is not counted as something the tape executes.
    pub fn of(tape: &[u8], ops: bff::OpSet) -> Self {
        Self {
            compressed_len: compress(tape).len() as u32,
            instruction_count: tape.iter().filter(|byte| ops.enables(**byte)).count() as u32,
        }
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

    let mut sizes: HashMap<u64, usize> = HashMap::new();
    for (id, _) in tagged() {
        *sizes.entry(id).or_insert(0) += 1;
    }
    let mut read: Vec<(u64, usize)> = sizes.into_iter().filter(|(_, held)| *held > 1).collect();
    // Largest first, and the lowest id of any that tie, so the reading is a function of
    // the world alone however the ids arrived from the map.
    read.sort_unstable_by_key(|(id, held)| (std::cmp::Reverse(*held), *id));
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
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TransitionTracker {
    candidate: Option<u64>,
    held: u32,
    settled: Option<u64>,
    last_epoch: Option<u64>,
}

/// The tracker's whole state, so a snapshot can carry it and a resumed run keeps the
/// measurement it had already made.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct TransitionState {
    pub candidate: Option<u64>,
    pub held: u32,
    pub settled: Option<u64>,
    pub last_epoch: Option<u64>,
}

impl TransitionTracker {
    pub fn from_state(state: TransitionState) -> Self {
        Self {
            candidate: state.candidate,
            held: state.held,
            settled: state.settled,
            last_epoch: state.last_epoch,
        }
    }

    pub fn state(&self) -> TransitionState {
        TransitionState {
            candidate: self.candidate,
            held: self.held,
            settled: self.settled,
            last_epoch: self.last_epoch,
        }
    }

    pub fn observe(&mut self, epoch: u64, measured: &Metrics) {
        if self.settled.is_some() || self.last_epoch == Some(epoch) {
            return;
        }
        self.last_epoch = Some(epoch);
        if measured.transition_candidate() {
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
        } else {
            self.candidate = None;
            self.held = 0;
        }
    }

    pub fn epoch(&self) -> Option<u64> {
        self.settled
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
        );
        assert_eq!(
            &encoded[crate::snapshot::HEADER_LEN..crate::snapshot::HEADER_LEN + payload.len()],
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

    #[test]
    fn repeated_samples_of_one_epoch_count_once() {
        let mut tracker = TransitionTracker::default();
        for _ in 0..10 {
            tracker.observe(5, &reading(0.1));
        }
        assert_eq!(tracker.epoch(), None);
    }
}
