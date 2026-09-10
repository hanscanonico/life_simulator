//! The replicator test (`docs/DESIGN.md` §1.2): a tape `T` is a replicator if executing
//! `T ++ R` for a random tape `R` leaves `T` in the second half for at least 3 of 4
//! trials.

use crate::bff;
use crate::rng::{self, Rng};

pub const TRIALS: u32 = 4;
pub const TRIALS_TO_PASS: u32 = 3;

pub fn is_replicator(tape: &[u8], max_steps: u32, rng: &mut Rng) -> bool {
    let len = tape.len();
    let mut buf = vec![0u8; len * 2];
    let mut passes = 0;
    for _ in 0..TRIALS {
        buf[..len].copy_from_slice(tape);
        for byte in &mut buf[len..] {
            *byte = rng::byte(rng);
        }
        bff::run(&mut buf, max_steps);
        if &buf[len..] == tape {
            passes += 1;
        }
    }
    passes >= TRIALS_TO_PASS
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

    #[test]
    fn the_handwritten_tape_replicates() {
        let tape = handwritten_replicator();
        let mut rng = rng::seeded(7, 0, 0);
        assert!(is_replicator(&tape, 8192, &mut rng));
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

    #[test]
    fn a_random_tape_does_not_replicate() {
        let mut rng = rng::seeded(11, 0, 0);
        let tape: Vec<u8> = (0..256).map(|_| rng::byte(&mut rng)).collect();
        assert!(!is_replicator(&tape, 8192, &mut rng));
    }

    #[test]
    fn a_tape_of_no_ops_does_not_replicate() {
        let mut rng = rng::seeded(13, 0, 0);
        assert!(!is_replicator(&[b'a'; 64], 8192, &mut rng));
    }
}
