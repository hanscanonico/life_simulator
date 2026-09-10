//! The observables of `docs/DESIGN.md` §1.2 and the transition tracker built on them.

use crate::bff;
use flate2::write::ZlibEncoder;
use flate2::Compression;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::io::Write;

/// `compress_ratio` below this, held for `TRANSITION_HOLD_SAMPLES` further samples, is
/// what counts as the transition to life.
pub const TRANSITION_THRESHOLD: f64 = 0.6;
pub const TRANSITION_HOLD_SAMPLES: u32 = 3;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Metrics {
    pub compress_ratio: f64,
    pub distinct_tapes: u64,
    pub top_share: f64,
    pub op_density: f64,
    pub replicator_count: u64,
    pub entropy_bits: f64,
    /// Share of the sampled epoch's interactions that ended with one tape byte-exactly
    /// copied over the other half — replication caught in situ, whoever the partner was.
    pub copy_rate: f64,
}

/// `zlib(all tapes).len / raw.len` — the BFF paper's headline signal.
pub fn compress_ratio(bytes: &[u8]) -> f64 {
    if bytes.is_empty() {
        return 0.0;
    }
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder
        .write_all(bytes)
        .expect("writing to a Vec cannot fail");
    let compressed = encoder.finish().expect("writing to a Vec cannot fail");
    compressed.len() as f64 / bytes.len() as f64
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

/// How many cells hold each distinct tape, keyed in a `BTreeMap` so iteration order is
/// the tapes' own order and never a hash seed's.
pub fn tape_counts(cells: &[u8], stride: usize) -> BTreeMap<&[u8], u64> {
    let mut counts: BTreeMap<&[u8], u64> = BTreeMap::new();
    for tape in cells.chunks_exact(stride) {
        *counts.entry(tape).or_insert(0) += 1;
    }
    counts
}

/// Distinct tapes ordered by population, ties broken by tape value so the order is a
/// function of the world alone.
pub fn by_population<'a>(counts: &BTreeMap<&'a [u8], u64>) -> Vec<(&'a [u8], u64)> {
    let mut ranked: Vec<(&'a [u8], u64)> = counts.iter().map(|(tape, n)| (*tape, *n)).collect();
    ranked.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
    ranked
}

/// The first sampled epoch at which `compress_ratio` drops below the threshold and stays
/// there — the primary dependent variable of every sweep.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TransitionTracker {
    candidate: Option<u64>,
    held: u32,
    settled: Option<u64>,
    last_epoch: Option<u64>,
}

impl TransitionTracker {
    pub fn observe(&mut self, epoch: u64, compress_ratio: f64) {
        if self.settled.is_some() || self.last_epoch == Some(epoch) {
            return;
        }
        self.last_epoch = Some(epoch);
        if compress_ratio < TRANSITION_THRESHOLD {
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
        let counts = tape_counts(&cells, 2);
        assert_eq!(counts.len(), 3);
        assert_eq!(counts[&[1, 1][..]], 3);

        let ranked = by_population(&counts);
        assert_eq!(ranked[0], (&[1u8, 1][..], 3));
        assert_eq!(ranked[1], (&[2u8, 2][..], 1), "ties break by tape value");
        assert_eq!(ranked[2], (&[3u8, 3][..], 1));
    }

    #[test]
    fn transition_settles_on_the_first_epoch_of_a_sustained_drop() {
        let mut tracker = TransitionTracker::default();
        tracker.observe(10, 0.9);
        tracker.observe(20, 0.5);
        tracker.observe(30, 0.9);
        assert_eq!(tracker.epoch(), None, "the drop did not hold");

        tracker.observe(40, 0.5);
        tracker.observe(50, 0.4);
        tracker.observe(60, 0.4);
        assert_eq!(tracker.epoch(), None, "only two further samples so far");
        tracker.observe(70, 0.3);
        assert_eq!(tracker.epoch(), Some(40));

        tracker.observe(80, 0.99);
        assert_eq!(tracker.epoch(), Some(40), "settled epochs never move");
    }

    #[test]
    fn repeated_samples_of_one_epoch_count_once() {
        let mut tracker = TransitionTracker::default();
        for _ in 0..10 {
            tracker.observe(5, 0.1);
        }
        assert_eq!(tracker.epoch(), None);
    }
}
