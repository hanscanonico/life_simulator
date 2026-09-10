//! The BFF interpreter (`docs/DESIGN.md` §1.1): ten ops over a byte buffer that is both
//! the program and the data, with two heads that wrap around the whole buffer.

pub const HEAD0_LEFT: u8 = b'<';
pub const HEAD0_RIGHT: u8 = b'>';
pub const HEAD1_LEFT: u8 = b'{';
pub const HEAD1_RIGHT: u8 = b'}';
pub const INC: u8 = b'+';
pub const DEC: u8 = b'-';
pub const COPY_TO_HEAD1: u8 = b'.';
pub const COPY_TO_HEAD0: u8 = b',';
pub const LOOP_START: u8 = b'[';
pub const LOOP_END: u8 = b']';

/// The ten instruction bytes; every other byte is a no-op.
pub const OPS: [u8; 10] = [
    HEAD0_LEFT,
    HEAD0_RIGHT,
    HEAD1_LEFT,
    HEAD1_RIGHT,
    INC,
    DEC,
    COPY_TO_HEAD1,
    COPY_TO_HEAD0,
    LOOP_START,
    LOOP_END,
];

pub fn is_op(byte: u8) -> bool {
    OPS.contains(&byte)
}

/// Why an execution stopped. Kept because the runner and the tests care about the
/// difference between "ran out of budget" and "the program ended".
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Halt {
    EndOfTape,
    StepLimit,
    UnmatchedBracket,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Outcome {
    pub halt: Halt,
    pub steps: u32,
}

/// Executes `tape` in place. The instruction pointer starts at 0 and runs forward; both
/// heads start at 0 and wrap modulo `tape.len()`. Bracket matches are scanned at
/// execution time, not precomputed, because the program rewrites itself as it runs.
pub fn run(tape: &mut [u8], max_steps: u32) -> Outcome {
    let len = tape.len();
    if len == 0 {
        return Outcome {
            halt: Halt::EndOfTape,
            steps: 0,
        };
    }

    let mut ip = 0usize;
    let mut head0 = 0usize;
    let mut head1 = 0usize;
    let mut steps = 0u32;

    while ip < len {
        if steps == max_steps {
            return Outcome {
                halt: Halt::StepLimit,
                steps,
            };
        }
        steps += 1;

        match tape[ip] {
            HEAD0_LEFT => head0 = (head0 + len - 1) % len,
            HEAD0_RIGHT => head0 = (head0 + 1) % len,
            HEAD1_LEFT => head1 = (head1 + len - 1) % len,
            HEAD1_RIGHT => head1 = (head1 + 1) % len,
            INC => tape[head0] = tape[head0].wrapping_add(1),
            DEC => tape[head0] = tape[head0].wrapping_sub(1),
            COPY_TO_HEAD1 => tape[head1] = tape[head0],
            COPY_TO_HEAD0 => tape[head0] = tape[head1],
            LOOP_START if tape[head0] == 0 => match match_forward(tape, ip) {
                Some(target) => ip = target,
                None => {
                    return Outcome {
                        halt: Halt::UnmatchedBracket,
                        steps,
                    }
                }
            },
            LOOP_END if tape[head0] != 0 => match match_backward(tape, ip) {
                Some(target) => ip = target,
                None => {
                    return Outcome {
                        halt: Halt::UnmatchedBracket,
                        steps,
                    }
                }
            },
            _ => {}
        }

        ip += 1;
    }

    Outcome {
        halt: Halt::EndOfTape,
        steps,
    }
}

fn match_forward(tape: &[u8], ip: usize) -> Option<usize> {
    let mut depth = 1usize;
    for (offset, byte) in tape.iter().enumerate().skip(ip + 1) {
        match *byte {
            LOOP_START => depth += 1,
            LOOP_END => {
                depth -= 1;
                if depth == 0 {
                    return Some(offset);
                }
            }
            _ => {}
        }
    }
    None
}

fn match_backward(tape: &[u8], ip: usize) -> Option<usize> {
    let mut depth = 1usize;
    for offset in (0..ip).rev() {
        match tape[offset] {
            LOOP_END => depth += 1,
            LOOP_START => {
                depth -= 1;
                if depth == 0 {
                    return Some(offset);
                }
            }
            _ => {}
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn exec(program: &str, tail: &[u8]) -> (Vec<u8>, Outcome) {
        let mut tape: Vec<u8> = program.bytes().collect();
        tape.extend_from_slice(tail);
        let outcome = run(&mut tape, 10_000);
        (tape, outcome)
    }

    #[test]
    fn inc_and_dec_wrap_the_byte_under_head0() {
        let (tape, outcome) = exec("+++", &[]);
        assert_eq!(tape[0], b'+'.wrapping_add(3));
        assert_eq!(outcome.halt, Halt::EndOfTape);
        assert_eq!(outcome.steps, 3);

        let mut tape = vec![b'-', 0];
        run(&mut tape, 10);
        assert_eq!(tape[0], b'-'.wrapping_sub(1));
    }

    #[test]
    fn copies_move_bytes_between_the_heads() {
        // head0 walks to the 7, then `.` writes it where head1 still sits.
        let mut tape = vec![b'>', b'>', b'>', b'>', b'>', 7, b'.', 0];
        run(&mut tape, 100);
        assert_eq!(tape[0], 7);

        // head1 wraps back to the 9, then `,` pulls it under head0.
        let mut tape = vec![b'{', b',', 0, 9];
        run(&mut tape, 100);
        assert_eq!(tape[0], 9);
    }

    #[test]
    fn heads_wrap_around_the_whole_buffer() {
        let mut tape = vec![b'<', b'+', 0, 0];
        run(&mut tape, 10);
        assert_eq!(tape[3], 1, "head0 wrapped to the last byte");

        let mut tape = vec![b'{', b'.', 0, 0];
        run(&mut tape, 10);
        assert_eq!(tape[3], b'{', "head1 wrapped to the last byte");
    }

    #[test]
    fn loop_start_skips_past_its_match_when_the_byte_is_zero() {
        let mut tape = vec![0, b'[', b'+', b'[', b'+', b']', b']', b'+', 0];
        run(&mut tape, 100);
        assert_eq!(tape[0], 1, "only the increment after the loop ran");
    }

    #[test]
    fn loop_end_jumps_back_while_the_byte_is_non_zero() {
        // head0 sits on a counter of 3; the body decrements it and advances head1.
        let mut tape = vec![3, b'[', b'}', b'-', b']', 0, 0, 0];
        let outcome = run(&mut tape, 100);
        assert_eq!(tape[0], 0);
        assert_eq!(outcome.halt, Halt::EndOfTape);
    }

    #[test]
    fn an_unmatched_bracket_halts() {
        let mut tape = vec![0, b'[', b'+'];
        assert_eq!(run(&mut tape, 100).halt, Halt::UnmatchedBracket);

        let mut tape = vec![1, b']', b'+'];
        assert_eq!(run(&mut tape, 100).halt, Halt::UnmatchedBracket);
    }

    #[test]
    fn an_unmatched_loop_end_on_a_zero_byte_is_a_no_op() {
        let mut tape = vec![0, b']', b'+'];
        let outcome = run(&mut tape, 100);
        assert_eq!(outcome.halt, Halt::EndOfTape);
        assert_eq!(tape[0], 1);
    }

    #[test]
    fn execution_stops_at_the_step_cap() {
        let mut tape = vec![1, b'[', b'>', b'<', b']'];
        let outcome = run(&mut tape, 64);
        assert_eq!(outcome.halt, Halt::StepLimit);
        assert_eq!(outcome.steps, 64);
    }

    #[test]
    fn every_other_byte_is_a_no_op() {
        let mut tape = vec![b'a', b'Z', 0, 200];
        let before = tape.clone();
        let outcome = run(&mut tape, 100);
        assert_eq!(tape, before);
        assert_eq!(outcome.steps, 4);
    }

    #[test]
    fn ops_are_the_ten_documented_bytes() {
        assert!(OPS.iter().all(|b| is_op(*b)));
        assert!(!is_op(b'a'));
        assert_eq!(OPS.len(), 10);
    }
}
