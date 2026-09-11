//! The observables of `docs/DESIGN.md` §1.2 and the transition tracker built on them.

use crate::bff;
use flate2::write::ZlibEncoder;
use flate2::Compression;
use serde::{Deserialize, Serialize};
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

/// Distinct tapes with their populations, ordered by population and ties broken by tape
/// value, so the ranking is a function of the world alone. Sorting the tapes and
/// run-length counting them costs a third of what a map keyed by whole tapes costs on a
/// soup of distinct tapes, and a few microseconds more than it once the soup has
/// converged on a handful.
pub fn ranked_tapes(cells: &[u8], stride: usize) -> Vec<(&[u8], u64)> {
    let mut tapes: Vec<&[u8]> = cells.chunks_exact(stride).collect();
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
    fn tapes_are_counted_and_ranked_by_population() {
        let cells = [1, 1, 2, 2, 1, 1, 3, 3, 1, 1];
        let ranked = ranked_tapes(&cells, 2);
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
        assert_eq!(ranked_tapes(&cells, 64), ranked_through_a_map(&cells, 64));
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
        let ranked = ranked_tapes(&cells, 64);
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
        let encoded = crate::snapshot::encode(
            &crate::snapshot::Header {
                substrate: crate::params::Substrate::Soup,
                width: 8,
                height: 8,
                tape_len: 64,
                epoch: 0,
                transition: TransitionState::default(),
            },
            &cells,
        );
        let payload = encoded.len() - crate::snapshot::HEADER_LEN;
        assert_eq!(
            compress_ratio_of(payload, cells.len()),
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
