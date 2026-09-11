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

/// The enabled instruction set of a run (`Params::ops`, DESIGN §1.3 sweep 5): a bit per
/// entry of `OPS`. A byte whose op is disabled is a no-op, exactly like a byte that is
/// not an op at all — it still costs a step. Bracket *matching* keeps reading every `[`
/// and `]` byte, disabled or not: the structure of a program does not depend on which
/// jumps are executable.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OpSet(u16);

impl OpSet {
    /// All ten ops — the default substrate of DESIGN §1.1.
    pub const ALL: Self = Self((1 << 10) - 1);

    /// The set named by `ops`, or the reason it is not a legal instruction set: a
    /// non-empty subset of the ten op bytes, each named at most once.
    pub fn parse(ops: &str) -> Result<Self, &'static str> {
        let mut bits = 0u16;
        for byte in ops.bytes() {
            let index = OPS
                .iter()
                .position(|op| *op == byte)
                .ok_or("every character must be one of <>{}+-.,[]")?;
            if bits & (1 << index) != 0 {
                return Err("no instruction may be named twice");
            }
            bits |= 1 << index;
        }
        if bits == 0 {
            return Err("at least one instruction must be enabled");
        }
        Ok(Self(bits))
    }

    pub fn enables(self, byte: u8) -> bool {
        OPS.iter()
            .position(|op| *op == byte)
            .is_some_and(|index| self.0 & (1 << index) != 0)
    }

    /// The byte-indexed form of the set. Callers that execute many tapes under one set —
    /// a soup epoch, the trials of one replicator test — build it once and hand it to
    /// `run_with_table`.
    pub fn table(self) -> OpTable {
        let mut table = [false; 256];
        for (index, op) in OPS.iter().enumerate() {
            table[*op as usize] = self.0 & (1 << index) != 0;
        }
        OpTable(table)
    }
}

/// A byte-indexed `OpSet`, so the interpreter's inner loop pays one array read instead of
/// a scan over `OPS`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OpTable([bool; 256]);

impl OpTable {
    fn enables(&self, byte: u8) -> bool {
        self.0[byte as usize]
    }
}

impl Default for OpSet {
    fn default() -> Self {
        Self::ALL
    }
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

/// Executes `tape` in place with every op enabled.
pub fn run(tape: &mut [u8], max_steps: u32) -> Outcome {
    run_with(tape, max_steps, OpSet::ALL)
}

/// Executes `tape` in place, running only the ops `enabled` names.
pub fn run_with(tape: &mut [u8], max_steps: u32, enabled: OpSet) -> Outcome {
    run_with_table(tape, max_steps, &enabled.table())
}

/// Executes `tape` in place under an already-built instruction table. The instruction
/// pointer starts at 0 and runs forward; both heads start at 0 and wrap modulo
/// `tape.len()`. Bracket matches are scanned at execution time, not precomputed, because
/// the program rewrites itself as it runs.
pub fn run_with_table(tape: &mut [u8], max_steps: u32, enabled: &OpTable) -> Outcome {
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
            byte if !enabled.enables(byte) => {}
            HEAD0_LEFT => head0 = step_left(head0, len),
            HEAD0_RIGHT => head0 = step_right(head0, len),
            HEAD1_LEFT => head1 = step_left(head1, len),
            HEAD1_RIGHT => head1 = step_right(head1, len),
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

/// A head moves one cell and wraps around the buffer. Written as a branch rather than
/// `% len`: `len` is a runtime value, so the modulo is a real integer division on the
/// four hottest ops.
fn step_left(head: usize, len: usize) -> usize {
    if head == 0 {
        len - 1
    } else {
        head - 1
    }
}

fn step_right(head: usize, len: usize) -> usize {
    let next = head + 1;
    if next == len {
        0
    } else {
        next
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
    fn a_disabled_op_is_a_no_op_and_the_enabled_ones_still_run() {
        // `>+` walks head0 onto the `+` and increments it; without `>` the increment
        // lands on the first byte instead, and the `>` byte itself costs its step.
        let without_move = OpSet::parse("+").expect("a legal set");
        let mut tape = vec![b'>', b'+', 0];
        let outcome = run_with(&mut tape, 100, without_move);
        assert_eq!(tape, vec![b'>'.wrapping_add(1), b'+', 0]);
        assert_eq!(outcome.steps, 3);

        let mut tape = vec![b'>', b'+', 0];
        run(&mut tape, 100);
        assert_eq!(tape, vec![b'>', b'+'.wrapping_add(1), 0]);
    }

    #[test]
    fn a_soup_without_loops_runs_straight_through_its_brackets() {
        let without_loops = OpSet::parse("<>{}+-.,").expect("a legal set");
        let mut tape = vec![3, b'[', b'-', b']'];
        let outcome = run_with(&mut tape, 100, without_loops);
        assert_eq!(tape[0], 2, "the body ran once, with no jump back to it");
        assert_eq!(outcome.halt, Halt::EndOfTape);
        assert_eq!(outcome.steps, 4);

        let mut tape = vec![3, b'[', b'-', b']'];
        let outcome = run(&mut tape, 100);
        assert_eq!(
            tape[0], 0,
            "the same loop runs to zero when `[]` is enabled"
        );
        assert_eq!(outcome.steps, 8);
    }

    #[test]
    fn an_op_set_is_a_non_empty_subset_named_once_each() {
        assert_eq!(OpSet::parse("<>{}+-.,[]"), Ok(OpSet::ALL));
        assert!(OpSet::parse("+-").expect("a legal set").enables(b'+'));
        assert!(!OpSet::parse("+-").expect("a legal set").enables(b'.'));
        assert!(!OpSet::ALL.enables(b'a'));

        assert!(OpSet::parse("").is_err());
        assert!(OpSet::parse("++").is_err());
        assert!(OpSet::parse("+a").is_err());
    }

    #[test]
    fn the_whole_instruction_set_runs_exactly_as_before() {
        let mut with_all = vec![3, b'[', b'}', b'-', b']', b'.', b',', b'<', 0];
        let mut by_default = with_all.clone();
        assert_eq!(
            run_with(&mut with_all, 100, OpSet::ALL),
            run(&mut by_default, 100)
        );
        assert_eq!(with_all, by_default);
    }

    #[test]
    fn a_prebuilt_table_runs_a_tape_exactly_as_its_op_set_does() {
        let ablated = OpSet::parse("<>{}+-.[]").expect("a legal set");
        let mut by_table = vec![3, b'[', b'}', b'-', b']', b'.', b',', b'<', b'>', 0];
        let mut by_set = by_table.clone();
        assert_eq!(
            run_with_table(&mut by_table, 100, &ablated.table()),
            run_with(&mut by_set, 100, ablated)
        );
        assert_eq!(by_table, by_set);
    }

    #[test]
    fn ops_are_the_ten_documented_bytes() {
        assert!(OPS.iter().all(|b| is_op(*b)));
        assert!(!is_op(b'a'));
        assert_eq!(OPS.len(), 10);
    }
}
