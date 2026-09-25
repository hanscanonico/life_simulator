//! The replicator test (`docs/DESIGN.md` §1.2): a tape `T` is a replicator if executing
//! `T ++ R` for a random tape `R` leaves `T` in the second half for at least 3 of 4
//! trials. Beside it sits the orientation-aware detector (`self_replicates`), which the
//! census's companion observables read (`docs/design_record.md`, 2026-09-25).

use crate::bff::{self, OpSet};
use crate::rng::{self, Rng};

pub const TRIALS: u32 = 4;
pub const TRIALS_TO_PASS: u32 = 3;

/// The orientation-aware detector's constants, in the one place `runner schema` exports
/// them from. The chain is odd — five runs, each against fresh noise — so a tape that
/// writes its reverse is compared after an even number of copies, in its own orientation
/// (the 2026 BFF paper's Algorithm 1, cubff's `CheckSelfRep`).
pub const SELF_REP_GENERATIONS: u32 = 5;
/// Independent chains per tape; odd, so a per-position majority never ties.
pub const SELF_REP_TRIALS: u32 = 5;
/// A tape passes when at least this share of its positions agree with the original by
/// majority: the paper's 48 of 64 bytes, as a ratio of integers so it scales exactly to
/// any length and is never a rounded 0.75.
pub const SELF_REP_AGREEMENT_NUMERATOR: usize = 3;
pub const SELF_REP_AGREEMENT_DENOMINATOR: usize = 4;
/// How many cells, drawn uniformly with replacement, one sample runs the detector on.
pub const SELF_REP_SAMPLE_CELLS: u32 = 256;

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

/// What the orientation-aware detector read of one tape. `aligned` is the paper's reading:
/// the carried half agrees with the tape position by position. `rotated` also accepts the
/// best cyclic rotation of that comparison — one rotation for every trial — so a copier
/// whose copies land a few bytes round the pair passes it too. `rotated` is never false
/// where `aligned` is true.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Verdict {
    pub aligned: bool,
    pub rotated: bool,
}

/// Whether `tape` reproduces itself down a chain of `SELF_REP_GENERATIONS` runs, in either
/// orientation. Each run is the soup's own interaction and the replicator test's buffer: the
/// tape of the moment and fresh noise of its length, `bff::run_with` on the fixed `2·len`
/// buffer under `max_steps`. The partner half then carries forward into the first half and
/// fresh noise refills the second, as cubff chains it. After the last run the first half
/// holds the fourth copy down the chain, and is compared with the original.
///
/// A tape that writes its own reverse, whose reverse runs the same program, is back in its
/// own orientation after four copies — the class the replicator test cannot see, since it
/// asks for `T` itself in the partner after one run. Every draw is from `rng`, which the
/// caller seeds on a stream of its own.
pub fn self_replicates(tape: &[u8], max_steps: u32, ops: OpSet, rng: &mut Rng) -> Verdict {
    let len = tape.len();
    if len == 0 {
        return Verdict::default();
    }
    let mut buf = vec![0u8; len * 2];
    let carried: Vec<Vec<u8>> = (0..SELF_REP_TRIALS)
        .map(|_| {
            buf[..len].copy_from_slice(tape);
            for generation in 0..SELF_REP_GENERATIONS {
                if generation > 0 {
                    buf.copy_within(len.., 0);
                }
                for byte in &mut buf[len..] {
                    *byte = rng::byte(rng);
                }
                bff::run_with(&mut buf, max_steps, ops);
            }
            buf[..len].to_vec()
        })
        .collect();
    let aligned = agrees_under(tape, &carried, 0);
    Verdict {
        aligned,
        rotated: aligned || (1..len).any(|rotation| agrees_under(tape, &carried, rotation)),
    }
}

/// Whether enough positions of `tape` agree, by majority over the trials, with the carried
/// halves read `rotation` bytes on. Gives up on a rotation as soon as too many positions
/// have disagreed for it to pass, which is almost at once for a tape that copies nothing.
fn agrees_under(tape: &[u8], carried: &[Vec<u8>], rotation: usize) -> bool {
    let len = tape.len();
    let needed = (len * SELF_REP_AGREEMENT_NUMERATOR).div_ceil(SELF_REP_AGREEMENT_DENOMINATOR);
    let allowed = len - needed;
    let mut disagreeing = 0;
    for (at, byte) in tape.iter().enumerate() {
        let from = (at + rotation) % len;
        let votes = carried.iter().filter(|half| half[from] == *byte).count();
        if votes * 2 <= carried.len() {
            disagreeing += 1;
            if disagreeing > allowed {
                return false;
            }
        }
    }
    true
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

/// A tape of `len` bytes that writes its own exact reverse over its partner — the
/// hand-written positive for the orientation-aware detector, and the class the replicator
/// test cannot see. `{` puts head1 on the pair's last byte and `[.>{]` copies head0
/// onto head1 with head1 walking left, so the partner ends holding the tape's exact
/// reverse. The loop meets no zero and runs out the budget, which leaves its own half
/// as it was. The tail is a second reverse copier written backwards — the pilot's
/// `[.<>>{]` — so the reverse is a copier too, and writes the tape back: the population
/// such a tape makes is `T` and `reverse(T)`, and the tape is not a palindrome.
pub fn handwritten_reverse_replicator(len: usize) -> Vec<u8> {
    two_ended(len, 0, b"{[.>{]", b"{[.<>>{]")
}

/// `head` at byte `margin`, and `tail` written backwards so that it ends `margin` bytes
/// before the end, on filler.
fn two_ended(len: usize, margin: usize, head: &[u8], tail: &[u8]) -> Vec<u8> {
    let mut tape = filler(len);
    tape[margin..margin + head.len()].copy_from_slice(head);
    let end = len - margin;
    for (at, byte) in tail.iter().enumerate() {
        tape[end - 1 - at] = *byte;
    }
    tape
}

/// Bytes that are neither an instruction nor zero, varying so that a tape read a few
/// bytes round from itself disagrees with itself: filler that repeats a single byte
/// would agree under any rotation.
fn filler(len: usize) -> Vec<u8> {
    const LETTERS: &[u8] = b"abcdefghijklmnopqrstuvwxyz";
    (0..len)
        .map(|at| LETTERS[(at * 7) % LETTERS.len()])
        .collect()
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

        let two_of_four = assay(&tape, 8192, OpSet::ALL, &mut rng::seeded(2, 0, 0));
        assert_eq!(two_of_four.passes, 2);
        assert_eq!(
            two_of_four.copy_cost, None,
            "two trials copied, but a tape that is not a replicator has no copy to price"
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

    /// Unlike the hand-written copier, this one's price depends on its partner: at this
    /// seed the three trials that copied paid 1 932, 2 058 and 2 067 steps while the
    /// fourth spun out on the whole 8 192 budget, so the reading is the middle price of a
    /// copy and never the price of spinning.
    #[test]
    fn the_parity_gated_replicator_reports_a_cost_from_its_passing_trials_only() {
        let tape = parity_gated_replicator();
        let read = assay(&tape, 8192, OpSet::ALL, &mut rng::seeded(0, 0, 0));
        assert_eq!(read.passes, 3);
        assert_eq!(read.copy_cost, Some(2_058));
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

    /// The three tape lengths the detector is asked to judge alike.
    const LENGTHS: [usize; 3] = [64, 128, 256];

    /// The hand-written forward copier at any length that divides 256: `-` `step` times
    /// turns the zero counter into `256 - step`, the counter loop walks head1 forward once
    /// per `step` decrements, so it stops on the pair's byte `len - 1` with the counter
    /// back at zero, and the copy is `handwritten_replicator`'s.
    fn forward_copier(len: usize) -> Vec<u8> {
        let step = 256 / len;
        let decrement = vec![b'-'; step];
        let mut program = vec![0];
        program.extend(&decrement);
        program.push(b'[');
        program.push(b'}');
        program.extend(&decrement);
        program.extend(b"]}.>}[.>}][");
        let mut tape = vec![b'a'; len];
        tape[..program.len()].copy_from_slice(&program);
        tape
    }

    /// A reverse copier whose two orientations reflect about different axes. `{{` starts
    /// head1 one byte short of the pair's end, so the partner holds the tape's reverse one
    /// byte round, with its last byte left to the noise; the tail's plain `{` reflects the
    /// other way. Each round trip moves the tape one byte, so four copies down the chain it
    /// sits two bytes round from where it started — the shape of the pilot's world 1087.
    fn rotated_reverse_copier(len: usize) -> Vec<u8> {
        two_ended(len, 2, b"{{[.>{]", b"{[.>{]")
    }

    fn verdict(tape: &[u8], seed: u64) -> Verdict {
        self_replicates(tape, 8192, OpSet::ALL, &mut rng::seeded(seed, 0, 0))
    }

    #[test]
    fn the_forward_copier_at_256_bytes_is_the_handwritten_one() {
        assert_eq!(forward_copier(256), handwritten_replicator());
    }

    #[test]
    fn a_forward_copier_self_replicates_at_every_length() {
        for len in LENGTHS {
            let tape = forward_copier(len);
            let mut rng = rng::seeded(3, 0, 0);
            assert!(is_replicator(&tape, 8192, OpSet::ALL, &mut rng), "{len}");
            assert_eq!(
                verdict(&tape, 3),
                Verdict {
                    aligned: true,
                    rotated: true
                },
                "{len}"
            );
        }
    }

    #[test]
    fn a_reverse_copier_writes_its_exact_reverse_into_its_partner() {
        for len in LENGTHS {
            let tape = handwritten_reverse_replicator(len);
            let mut reversed = tape.clone();
            reversed.reverse();
            assert_ne!(tape, reversed, "not a palindrome");
            let mut buf = tape.clone();
            let mut rng = rng::seeded(5, 0, 0);
            buf.extend((0..len).map(|_| rng::byte(&mut rng)));
            bff::run(&mut buf, 8192);
            assert_eq!(&buf[len..], &reversed[..], "{len}");
            assert_eq!(&buf[..len], &tape[..], "{len}: its own half is untouched");
        }
    }

    /// The contrast the detector exists for: the replicator test asks for `T` itself in the
    /// partner, and a reverse copier never writes it there.
    #[test]
    fn a_reverse_copier_self_replicates_where_the_replicator_test_sees_nothing() {
        for len in LENGTHS {
            let tape = handwritten_reverse_replicator(len);
            let read = assay(&tape, 8192, OpSet::ALL, &mut rng::seeded(5, 0, 0));
            assert_eq!(read.passes, 0, "{len}");
            assert_eq!(
                verdict(&tape, 5),
                Verdict {
                    aligned: true,
                    rotated: true
                },
                "{len}"
            );
        }
    }

    #[test]
    fn a_rotated_reverse_copier_passes_only_under_rotation() {
        for len in LENGTHS {
            let tape = rotated_reverse_copier(len);
            assert!(!is_replicator(
                &tape,
                8192,
                OpSet::ALL,
                &mut rng::seeded(9, 0, 0)
            ));
            assert_eq!(
                verdict(&tape, 9),
                Verdict {
                    aligned: false,
                    rotated: true
                },
                "{len}"
            );
        }
    }

    #[test]
    fn random_tapes_do_not_self_replicate() {
        for len in LENGTHS {
            let mut rng = rng::seeded(11, 0, 0);
            for _ in 0..8 {
                let tape: Vec<u8> = (0..len).map(|_| rng::byte(&mut rng)).collect();
                assert_eq!(
                    self_replicates(&tape, 8192, OpSet::ALL, &mut rng),
                    Verdict::default(),
                    "{len}"
                );
            }
        }
    }

    #[test]
    fn a_tape_of_no_ops_does_not_self_replicate() {
        assert_eq!(verdict(&filler(64), 13), Verdict::default());
        assert_eq!(verdict(&[], 13), Verdict::default());
    }

    #[test]
    fn a_copier_whose_copy_op_is_ablated_does_not_self_replicate() {
        let without_copy_to_head1 = OpSet::parse("<>{}+-,[]").expect("a legal set");
        for tape in [forward_copier(64), handwritten_reverse_replicator(64)] {
            let read = self_replicates(
                &tape,
                8192,
                without_copy_to_head1,
                &mut rng::seeded(7, 0, 0),
            );
            assert_eq!(read, Verdict::default());
        }
    }

    /// Majority, not unanimity, and three quarters, not all: the pass is read off the
    /// agreement count exactly at the boundary.
    #[test]
    fn three_quarters_of_the_positions_agreeing_is_a_pass_and_one_fewer_is_not() {
        let tape = filler(64);
        let mut carried = tape.clone();
        for byte in &mut carried[..16] {
            *byte = 0;
        }
        let trials = vec![carried.clone(), carried.clone(), tape.clone()];
        assert!(agrees_under(&tape, &trials, 0), "48 of 64 agree");
        carried[16] = 0;
        let trials = vec![carried.clone(), carried, tape.clone()];
        assert!(!agrees_under(&tape, &trials, 0), "47 of 64 agree");
    }

    #[test]
    fn a_tape_of_no_ops_does_not_replicate() {
        let mut rng = rng::seeded(13, 0, 0);
        assert!(!is_replicator(&[b'a'; 64], 8192, OpSet::ALL, &mut rng));
    }
}
