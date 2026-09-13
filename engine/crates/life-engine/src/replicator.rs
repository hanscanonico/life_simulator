//! The replicator test (`docs/DESIGN.md` §1.2): a tape `T` is a replicator if executing
//! `T ++ R` for a random tape `R` leaves `T` in the second half for at least 3 of 4
//! trials.

use crate::bff::{self, OpSet};
use crate::rng::{self, Rng};

pub const TRIALS: u32 = 4;
pub const TRIALS_TO_PASS: u32 = 3;

/// What the replicator test read of one tape: how many trials it passed, and what a copy
/// cost it when it worked.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Assay {
    pub passes: u32,
    /// Interpreter steps per byte-exact copy: the median over the passing trials, lower of
    /// the two middles on an even count. `None` unless the tape replicates.
    pub copy_cost: Option<u32>,
}

impl Assay {
    pub fn replicates(&self) -> bool {
        self.passes >= TRIALS_TO_PASS
    }
}

pub fn is_replicator(tape: &[u8], max_steps: u32, ops: OpSet, rng: &mut Rng) -> bool {
    assay(tape, max_steps, ops, rng).replicates()
}

/// Runs the `TRIALS` trials and reads both observables off them. The cost is taken from
/// the very same runs the test performs, in the same order and off the same RNG stream: a
/// trial is never re-run to measure it.
pub fn assay(tape: &[u8], max_steps: u32, ops: OpSet, rng: &mut Rng) -> Assay {
    let len = tape.len();
    let mut buf = vec![0u8; len * 2];
    let mut costs = Vec::with_capacity(TRIALS as usize);
    for _ in 0..TRIALS {
        buf[..len].copy_from_slice(tape);
        for byte in &mut buf[len..] {
            *byte = rng::byte(rng);
        }
        let outcome = bff::run_with(&mut buf, max_steps, ops);
        if &buf[len..] == tape {
            costs.push(outcome.steps);
        }
    }
    let passes = costs.len() as u32;
    let copy_cost = (passes >= TRIALS_TO_PASS)
        .then(|| median(&mut costs))
        .flatten();
    Assay { passes, copy_cost }
}

/// The lower of the two middles on an even count, so the reading is always a cost some
/// trial actually paid.
fn median(steps: &mut [u32]) -> Option<u32> {
    steps.sort_unstable();
    steps.get((steps.len().checked_sub(1)?) / 2).copied()
}

/// A 256-byte tape that copies itself over its partner — written by hand, so the test
/// suite has a known positive for the replicator test.
///
/// Byte 0 is both the loop counter and the sentinel that ends the copy. `-` turns it into
/// 255, the first loop walks head1 forward 255 times and leaves the counter back at 0,
/// one more `}` puts head1 on the partner's first byte. The copy then writes byte 0 (a
/// zero) across, so when head0 reaches it 256 bytes later the loop test reads a zero and
/// stops — exactly one tape copied. The trailing `[` is unmatched on a zero byte, which
/// halts execution before the instruction pointer can run into the fresh copy.
pub fn handwritten_replicator() -> Vec<u8> {
    const LEN: usize = 256;
    const FILLER: u8 = b'a';
    let mut tape = vec![FILLER; LEN];
    let program: &[u8] = &[
        0, // counter and end-of-copy sentinel
        b'-', b'[', b'}', b'-', b']', // head1 += 255, counter back to 0
        b'}', // head1 now on the partner's first byte
        b'.', b'>', b'}', // copy byte 0, advance both heads
        b'[', b'.', b'>', b'}', b']', // copy the remaining 255 bytes
        b'[', // unmatched on a zero byte: halt
    ];
    tape[..program.len()].copy_from_slice(program);
    tape
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The cost of one copy by `handwritten_replicator`, derived in
    /// `the_handwritten_tapes_copy_cost_is_known`.
    const COPY_COST: u32 = 1_794;

    #[test]
    fn the_handwritten_tape_replicates() {
        let tape = handwritten_replicator();
        let mut rng = rng::seeded(7, 0, 0);
        assert!(is_replicator(&tape, 8192, OpSet::ALL, &mut rng));
    }

    #[test]
    fn the_handwritten_tape_stops_replicating_when_its_copy_op_is_ablated() {
        let tape = handwritten_replicator();
        let without_copy_to_head1 = OpSet::parse("<>{}+-,[]").expect("a legal set");
        let mut rng = rng::seeded(7, 0, 0);
        assert!(!is_replicator(&tape, 8192, without_copy_to_head1, &mut rng));
    }

    #[test]
    fn it_copies_itself_over_a_random_partner() {
        let tape = handwritten_replicator();
        let mut rng = rng::seeded(7, 0, 0);
        let mut buf = tape.clone();
        buf.extend((0..tape.len()).map(|_| rng::byte(&mut rng)));
        let outcome = bff::run(&mut buf, 8192);
        assert_eq!(&buf[tape.len()..], &tape[..]);
        assert_eq!(outcome.halt, bff::Halt::UnmatchedBracket);
        assert!(outcome.steps < 8192, "{}", outcome.steps);
    }

    /// The hand-written copier with a parity gate in front of the copy: `<` walks head0
    /// onto the partner's last byte and `[--]` decrements it by two, which reaches zero on
    /// an even byte and wraps forever on an odd one. So the tape copies itself for half
    /// the partners and burns the whole step budget for the other half — which is what
    /// puts the three-of-four boundary itself under test.
    fn parity_gated_replicator() -> Vec<u8> {
        const LEN: usize = 256;
        let mut tape = vec![b'a'; LEN];
        let program: &[u8] = &[
            0, b'-', b'[', b'}', b'-', b']', b'}', // head1 onto the partner's first byte
            b'<', b'[', b'-', b'-', b']', b'>', // even partner tail: through; odd: spin
            b'.', b'>', b'}', b'[', b'.', b'>', b'}', b']', b'[',
        ];
        tape[..program.len()].copy_from_slice(program);
        tape
    }

    #[test]
    fn the_parity_gate_decides_a_single_trial() {
        let tape = parity_gated_replicator();
        for (tail, expected) in [(200u8, true), (201, false)] {
            let mut buf = tape.clone();
            buf.extend(std::iter::repeat_n(b'z', tape.len()));
            *buf.last_mut().expect("the buffer is not empty") = tail;
            bff::run(&mut buf, 8192);
            assert_eq!(
                buf[tape.len()..] == tape[..],
                expected,
                "partner tail {tail}"
            );
        }
    }

    #[test]
    fn two_passing_trials_of_four_are_not_enough() {
        let tape = parity_gated_replicator();

        assert_eq!(
            assay(&tape, 8192, OpSet::ALL, &mut rng::seeded(0, 0, 0)).passes,
            3
        );
        assert!(is_replicator(
            &tape,
            8192,
            OpSet::ALL,
            &mut rng::seeded(0, 0, 0)
        ));

        assert_eq!(
            assay(&tape, 8192, OpSet::ALL, &mut rng::seeded(2, 0, 0)).passes,
            2
        );
        assert!(!is_replicator(
            &tape,
            8192,
            OpSet::ALL,
            &mut rng::seeded(2, 0, 0)
        ));
    }

    /// The hand-written copier's cost is arithmetic, not luck: one no-op byte, `-`, `[`,
    /// 255 turns of the three-op counter loop, `}`, then `.`, `>`, `}` and `[` before 255
    /// turns of the four-op copy loop, and the unmatched `[` that halts it. The partner's
    /// bytes never enter the count, so every trial pays the same price and the median is
    /// that price.
    #[test]
    fn the_handwritten_tapes_copy_cost_is_known() {
        let tape = handwritten_replicator();
        let mut rng = rng::seeded(7, 0, 0);
        let read = assay(&tape, 8192, OpSet::ALL, &mut rng);
        assert!(read.replicates());
        assert_eq!(read.copy_cost, Some(COPY_COST));
    }

    #[test]
    fn the_copy_cost_is_none_for_a_tape_that_does_not_replicate() {
        let mut rng = rng::seeded(11, 0, 0);
        let tape: Vec<u8> = (0..256).map(|_| rng::byte(&mut rng)).collect();
        let read = assay(&tape, 8192, OpSet::ALL, &mut rng);
        assert!(!read.replicates());
        assert_eq!(read.copy_cost, None);
    }

    /// The trials that spin out burn the whole budget; the cost must come from the trials
    /// that copied.
    #[test]
    fn the_parity_gated_replicator_reports_a_cost_from_its_passing_trials_only() {
        let tape = parity_gated_replicator();
        let read = assay(&tape, 8192, OpSet::ALL, &mut rng::seeded(0, 0, 0));
        assert_eq!(read.passes, 3);
        let cost = read.copy_cost.expect("a passing tape reports a cost");
        assert!(cost < 8192, "{cost}");
    }

    #[test]
    fn the_median_takes_the_lower_middle_of_an_even_count() {
        assert_eq!(median(&mut []), None);
        assert_eq!(median(&mut [5]), Some(5));
        assert_eq!(median(&mut [9, 3]), Some(3));
        assert_eq!(median(&mut [9, 3, 5]), Some(5));
        assert_eq!(median(&mut [9, 3, 5, 7]), Some(5));
    }

    #[test]
    fn a_random_tape_does_not_replicate() {
        let mut rng = rng::seeded(11, 0, 0);
        let tape: Vec<u8> = (0..256).map(|_| rng::byte(&mut rng)).collect();
        assert!(!is_replicator(&tape, 8192, OpSet::ALL, &mut rng));
    }

    #[test]
    fn a_tape_of_no_ops_does_not_replicate() {
        let mut rng = rng::seeded(13, 0, 0);
        assert!(!is_replicator(&[b'a'; 64], 8192, OpSet::ALL, &mut rng));
    }
}
