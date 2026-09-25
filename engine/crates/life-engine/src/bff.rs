//! The BFF interpreter (`docs/DESIGN.md` §1.1): ten ops over a byte buffer that is both
//! the program and the data, with two heads that wrap around the whole buffer.

use serde::{Deserialize, Serialize};

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

/// The steal op (`docs/DESIGN.md` §1.1): moves energy from the partner cell's stock to the
/// stock of the cell whose code is executing. Deliberately not one of `OPS` — those ten are
/// the BFF instruction set `op_density` reads and `ops` ablates, and this byte is an
/// instruction only for a run whose `steal_amount` is set. `$` is a byte no BFF program has
/// ever meant anything by, and it is the one character on the keyboard that says "money".
pub const STEAL: u8 = b'$';

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

    /// A byte-indexed lookup, built once per execution so the interpreter's inner loop
    /// pays one array read instead of a scan over `OPS`.
    fn table(self) -> [bool; 256] {
        let mut table = [false; 256];
        for (index, op) in OPS.iter().enumerate() {
            table[*op as usize] = self.0 & (1 << index) != 0;
        }
        table
    }
}

impl Default for OpSet {
    fn default() -> Self {
        Self::ALL
    }
}

/// Why an execution stopped. Kept because the runner and the tests care about the
/// difference between "ran out of budget" and "the program ended".
///
/// `EnergySpent` is never produced here: the interpreter knows only the cap it was handed,
/// and it is `world::halt_reason` that tells the two budgets apart.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Halt {
    EndOfTape,
    StepLimit,
    EnergySpent,
    UnmatchedBracket,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Outcome {
    pub halt: Halt,
    pub steps: u32,
    /// How many steal ops each half of the pair executed — the first tape's code, then the
    /// second's. Always `[0, 0]` where the op is off, which is every run at the defaults.
    /// The interpreter counts them and moves no energy itself: what a steal is worth is the
    /// world's economy, and the world settles it once the interaction has been paid for.
    pub steals: [u32; 2],
}

/// Whether the steal byte is an instruction in this execution, and where the pair the
/// interpreter is running was joined (`docs/DESIGN.md` §1.1). The thief is the half of the
/// pair the instruction pointer is in: the first tape's code before `split`, the second's
/// after it — which under a `host` interaction is always the first, since the pointer never
/// leaves its code.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Stealing {
    /// The steal byte as the plain no-op it is for every run that has not switched it on.
    Off,
    /// The steal byte as an instruction, over a pair whose first tape ends at this split.
    At(usize),
}

impl Stealing {
    fn split(self) -> Option<usize> {
        match self {
            Self::Off => None,
            Self::At(split) => Some(split),
        }
    }
}

/// The bounds one execution is held to: the steps it may take, the ops it executes, the
/// length its tape may grow to, and how much of the buffer in front of it is code.
#[derive(Debug, Clone, Copy)]
pub struct Bounds {
    pub max_steps: u32,
    pub enabled: OpSet,
    pub cap: usize,
    pub code_len: usize,
}

/// Executes `tape` in place with every op enabled, at its own length.
pub fn run(tape: &mut Vec<u8>, max_steps: u32) -> Outcome {
    run_with(tape, max_steps, OpSet::ALL)
}

/// Executes `tape` in place at its own length, running only the ops `enabled` names.
pub fn run_with(tape: &mut Vec<u8>, max_steps: u32, enabled: OpSet) -> Outcome {
    let cap = tape.len();
    run_growing(tape, max_steps, enabled, cap)
}

/// Executes `tape` in place, running only the ops `enabled` names, and lets it lengthen
/// up to `cap` bytes. The instruction pointer starts at 0 and runs forward; both heads
/// start at 0 and wrap modulo the tape's current length. Bracket matches are scanned at
/// execution time, not precomputed, because the program rewrites itself as it runs.
///
/// Growth is the one thing `cap` adds (DESIGN §1.3, sweep 8): a head stepping right off
/// the last byte appends a zero and moves onto it while there is room, and wraps to the
/// front once there is not. A `cap` equal to `tape.len()` is the fixed tape of §1.1 —
/// there is never room, so the loop below executes the identical instruction stream.
pub fn run_growing(tape: &mut Vec<u8>, max_steps: u32, enabled: OpSet, cap: usize) -> Outcome {
    run_bounded(tape, max_steps, enabled, cap, cap)
}

/// Executes `tape` as `run_growing` does, with the instruction pointer confined to the
/// first `code_len` bytes: the asymmetric execution mode of DESIGN §1.1, where only the
/// host's own bytes are code and everything past them is read/write substrate. Both heads
/// still range over the whole buffer, so the partner is data a program reads and writes;
/// a jump whose matching bracket lies past the code lands outside it and ends the run,
/// exactly as stepping off the end does.
///
/// A `code_len` at the `cap` is the symmetric substrate of §1.1 — the buffer never
/// exceeds its cap, so the pointer stops where it always stopped, at the end of the
/// buffer, and the identical instruction stream runs.
pub fn run_bounded(
    tape: &mut Vec<u8>,
    max_steps: u32,
    enabled: OpSet,
    cap: usize,
    code_len: usize,
) -> Outcome {
    run_stealing(
        tape,
        Bounds {
            max_steps,
            enabled,
            cap,
            code_len,
        },
        Stealing::Off,
    )
}

/// Executes `tape` as `run_bounded` does, with the steal byte reading as the op of DESIGN
/// §1.1 where `stealing` says so: the run counts the steals each half of the pair executed
/// and the world settles what they move. Switched off — every run at the defaults — the
/// byte is not in the table the loop reads, so it is the no-op it has always been and the
/// identical instruction stream runs.
pub fn run_stealing(tape: &mut Vec<u8>, bounds: Bounds, stealing: Stealing) -> Outcome {
    let Bounds {
        max_steps,
        enabled,
        cap,
        code_len,
    } = bounds;
    let split = stealing.split();
    let mut enabled = enabled.table();
    enabled[STEAL as usize] = split.is_some();
    let split = split.unwrap_or(0);
    let mut steals = [0u32; 2];
    let mut len = tape.len();
    if len == 0 {
        return Outcome {
            halt: Halt::EndOfTape,
            steps: 0,
            steals,
        };
    }

    let mut ip = 0usize;
    let mut head0 = 0usize;
    let mut head1 = 0usize;
    let mut steps = 0u32;
    // The pointer stops at the end of the code or at the end of the buffer, whichever
    // comes first. Held rather than compared each step: only a head claiming a byte can
    // move it, so the inner loop pays the one comparison it always paid.
    let mut bound = len.min(code_len);

    while ip < bound {
        if steps == max_steps {
            return Outcome {
                halt: Halt::StepLimit,
                steps,
                steals,
            };
        }
        steps += 1;

        match tape[ip] {
            byte if !enabled[byte as usize] => {}
            HEAD0_LEFT => head0 = (head0 + len - 1) % len,
            HEAD0_RIGHT => {
                head0 = step_right(head0, &mut len, cap, tape);
                bound = len.min(code_len);
            }
            HEAD1_LEFT => head1 = (head1 + len - 1) % len,
            HEAD1_RIGHT => {
                head1 = step_right(head1, &mut len, cap, tape);
                bound = len.min(code_len);
            }
            INC => tape[head0] = tape[head0].wrapping_add(1),
            DEC => tape[head0] = tape[head0].wrapping_sub(1),
            COPY_TO_HEAD1 => tape[head1] = tape[head0],
            COPY_TO_HEAD0 => tape[head0] = tape[head1],
            STEAL => steals[usize::from(ip >= split)] += 1,
            LOOP_START if tape[head0] == 0 => match match_forward(tape, ip) {
                Some(target) => ip = target,
                None => {
                    return Outcome {
                        halt: Halt::UnmatchedBracket,
                        steps,
                        steals,
                    }
                }
            },
            LOOP_END if tape[head0] != 0 => match match_backward(tape, ip) {
                Some(target) => ip = target,
                None => {
                    return Outcome {
                        halt: Halt::UnmatchedBracket,
                        steps,
                        steals,
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
        steals,
    }
}

/// A head one byte to the right: onto a fresh zero byte at the end while the tape may
/// still lengthen, and round to the front once it may not.
fn step_right(head: usize, len: &mut usize, cap: usize, tape: &mut Vec<u8>) -> usize {
    if head + 1 == *len {
        if *len >= cap {
            return 0;
        }
        tape.push(0);
        *len += 1;
    }
    head + 1
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

/// Which way round a copy holds its source: the source's own bytes in order, its bytes last
/// to first, or both at once, which only a palindrome can be.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Orientation {
    Forward,
    Reverse,
    Both,
}

/// The first moment a watched run held a complete image: the steps executed by then, and
/// which way round the image lies.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Image {
    pub steps: u32,
    pub orientation: Orientation,
}

/// Runs `pair` — a tape and its partner, the fixed `2·len` buffer of the replicator test —
/// as `run_with` runs it, and stops at the first step after which the partner half holds
/// `source` byte-exact, in either orientation. `None` when the budget runs out or the
/// program ends first. `copy_latency` reads this (DESIGN §1.2).
///
/// A replica of `run_stealing` on a buffer that cannot grow, with the steal byte off and
/// every byte code, so it executes the identical instruction stream; the tests pin it step
/// for step against `run_with`. It is a separate loop so the watch — two counts of the
/// partner positions that still disagree with the image, kept current at every write —
/// never costs the soup's own interactions anything.
pub fn first_image(
    pair: &mut [u8],
    source: &[u8],
    max_steps: u32,
    enabled: OpSet,
) -> Option<Image> {
    let half = source.len();
    let len = pair.len();
    if half == 0 || len != 2 * half {
        return None;
    }
    let enabled = enabled.table();
    let mut watch = ImageWatch::new(pair, source);

    let mut ip = 0usize;
    let mut head0 = 0usize;
    let mut head1 = 0usize;
    let mut steps = 0u32;
    while ip < len {
        if let Some(orientation) = watch.complete() {
            return Some(Image { steps, orientation });
        }
        if steps == max_steps {
            return None;
        }
        steps += 1;

        let write = match pair[ip] {
            byte if !enabled[byte as usize] => None,
            HEAD0_LEFT => {
                head0 = (head0 + len - 1) % len;
                None
            }
            HEAD0_RIGHT => {
                head0 = (head0 + 1) % len;
                None
            }
            HEAD1_LEFT => {
                head1 = (head1 + len - 1) % len;
                None
            }
            HEAD1_RIGHT => {
                head1 = (head1 + 1) % len;
                None
            }
            INC => Some((head0, pair[head0].wrapping_add(1))),
            DEC => Some((head0, pair[head0].wrapping_sub(1))),
            COPY_TO_HEAD1 => Some((head1, pair[head0])),
            COPY_TO_HEAD0 => Some((head0, pair[head1])),
            LOOP_START if pair[head0] == 0 => {
                ip = match_forward(pair, ip)?;
                None
            }
            LOOP_END if pair[head0] != 0 => {
                ip = match_backward(pair, ip)?;
                None
            }
            _ => None,
        };
        if let Some((at, byte)) = write {
            watch.write(pair, at, byte);
        }

        ip += 1;
    }
    watch
        .complete()
        .map(|orientation| Image { steps, orientation })
}

/// How many partner positions still disagree with the source read forward and read
/// reversed, so a complete image is two comparisons with zero rather than a scan.
struct ImageWatch<'a> {
    source: &'a [u8],
    forward: usize,
    reverse: usize,
}

impl<'a> ImageWatch<'a> {
    fn new(pair: &[u8], source: &'a [u8]) -> Self {
        let partner = &pair[source.len()..];
        Self {
            source,
            forward: partner.iter().zip(source).filter(|(a, b)| a != b).count(),
            reverse: partner
                .iter()
                .zip(source.iter().rev())
                .filter(|(a, b)| a != b)
                .count(),
        }
    }

    fn write(&mut self, pair: &mut [u8], at: usize, byte: u8) {
        let half = self.source.len();
        if at >= half {
            let position = at - half;
            let forward = self.source[position];
            let reverse = self.source[half - 1 - position];
            let old = pair[at];
            self.forward =
                self.forward + usize::from(byte != forward) - usize::from(old != forward);
            self.reverse =
                self.reverse + usize::from(byte != reverse) - usize::from(old != reverse);
        }
        pair[at] = byte;
    }

    fn complete(&self) -> Option<Orientation> {
        match (self.forward == 0, self.reverse == 0) {
            (true, true) => Some(Orientation::Both),
            (true, false) => Some(Orientation::Forward),
            (false, true) => Some(Orientation::Reverse),
            (false, false) => None,
        }
    }
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

    /// The growth rule of DESIGN §1.3, sweep 8: a head stepping right off the end claims a
    /// fresh zero byte while the cap allows it, and wraps once it does not.
    #[test]
    fn a_head_stepping_off_the_end_lengthens_the_tape_while_there_is_room() {
        let mut grown = vec![b'>'; 3];
        let outcome = run_growing(&mut grown, 100, OpSet::ALL, 4);
        assert_eq!(grown, vec![b'>', b'>', b'>', 0]);
        assert_eq!(outcome.steps, 4, "the claimed byte costs its step too");

        let mut head1 = vec![b'}'; 3];
        run_growing(&mut head1, 100, OpSet::ALL, 4);
        assert_eq!(head1, vec![b'}', b'}', b'}', 0], "either head claims bytes");
    }

    #[test]
    fn a_tape_at_its_cap_wraps_instead_of_growing() {
        let mut tape = vec![b'>'; 3];
        let outcome = run_growing(&mut tape, 100, OpSet::ALL, 3);
        assert_eq!(tape, vec![b'>'; 3]);
        assert_eq!(outcome.steps, 3);
    }

    /// The fixed tape of §1.1 is a cap at the tape's own length, and it must execute the
    /// identical instruction stream: growth is the one thing a wider cap adds.
    #[test]
    fn a_cap_at_the_tapes_own_length_runs_it_exactly_as_a_fixed_tape() {
        let program = vec![3, b'[', b'}', b'-', b']', b'.', b',', b'<', b'>', b'>', 0];
        let mut fixed = program.clone();
        let mut capped = program.clone();
        let len = program.len();
        assert_eq!(
            run_with(&mut fixed, 100, OpSet::ALL),
            run_growing(&mut capped, 100, OpSet::ALL, len)
        );
        assert_eq!(fixed, capped);
    }

    /// Growth is the program's own copying and not a gift: a loop walks head1 off the end,
    /// claims a byte, and the copy that follows writes into the space it claimed.
    #[test]
    fn a_program_copies_into_the_space_it_claimed() {
        let mut tape = vec![7, b'[', b'}', b'-', b']', b'>', b'.'];
        let outcome = run_growing(&mut tape, 1_000, OpSet::ALL, 9);
        assert_eq!(tape.len(), 8);
        assert_eq!(tape[7], b'[', "the copy landed in the claimed byte");
        assert_eq!(outcome.halt, Halt::EndOfTape);
    }

    /// The asymmetric mode of §1.1: the pointer stops at the end of the host's code, so
    /// the partner's increments are bytes and not instructions. Unbounded, the very same
    /// pair runs them.
    #[test]
    fn a_bounded_pointer_never_executes_a_byte_past_the_host_code() {
        let pair = vec![b'a', b'a', b'+', b'+', b'+'];

        let cap = pair.len();
        let mut hosted = pair.clone();
        let outcome = run_bounded(&mut hosted, 100, OpSet::ALL, cap, 2);
        assert_eq!(hosted, pair, "the partner's ops never ran");
        assert_eq!(outcome.steps, 2, "the pointer stepped the host's two bytes");
        assert_eq!(outcome.halt, Halt::EndOfTape);

        let mut whole = pair.clone();
        run_bounded(&mut whole, 100, OpSet::ALL, cap, cap);
        assert_eq!(
            whole[0],
            b'a'.wrapping_add(3),
            "unbounded they are instructions"
        );
    }

    /// Both heads still range over the whole buffer under a bound: the host's own code
    /// walks head1 into the partner and writes there.
    #[test]
    fn a_bounded_run_still_reaches_the_partner_with_both_heads() {
        let mut pair = vec![b'}', b'}', b'}', b'}', b'}', b'}', b'.', 0, 0, 0];
        let cap = pair.len();
        let outcome = run_bounded(&mut pair, 100, OpSet::ALL, cap, 7);
        assert_eq!(pair[6], b'}', "the copy landed in the partner's first byte");
        assert_eq!(outcome.steps, 7);
    }

    /// Instrumented over random pairs: with the jumps left out the pointer only moves
    /// forward, so one step is one byte of code and the step count reads how far it got.
    /// A bound one byte wide of the host's length fails this.
    #[test]
    fn a_bounded_run_steps_no_byte_of_the_partner() {
        let straight = OpSet::parse("<>{}+-.,").expect("a legal set");
        let mut rng = crate::rng::seeded(7, 0, 0);
        for _ in 0..200 {
            let host: Vec<u8> = (0..24).map(|_| crate::rng::byte(&mut rng)).collect();
            let mut pair = host.clone();
            pair.extend((0..24).map(|_| crate::rng::byte(&mut rng)));
            let cap = pair.len();

            let outcome = run_bounded(&mut pair, 10_000, straight, cap, host.len());

            assert!(
                outcome.steps as usize <= host.len(),
                "{} steps over {} bytes of code",
                outcome.steps,
                host.len()
            );
            assert_eq!(outcome.halt, Halt::EndOfTape);
        }
    }

    /// Bracket matching still scans the whole buffer (DESIGN §1.1): a `[` whose match lies
    /// in the partner jumps the pointer out of the code and ends the run there, rather
    /// than reading as the unmatched bracket the same byte would be under a second
    /// matching rule confined to the code. Either way the partner's `+` never runs.
    #[test]
    fn a_bracket_matched_in_the_partner_jumps_the_pointer_out_of_the_code() {
        let matched = vec![0, b'[', b'+', 0, 0, b']'];
        let mut jumped = matched.clone();
        let outcome = run_bounded(&mut jumped, 100, OpSet::ALL, matched.len(), 3);
        assert_eq!(outcome.halt, Halt::EndOfTape, "the jump left the code");
        assert_eq!(outcome.steps, 2, "the zero byte and the bracket");
        assert_eq!(jumped, matched, "the byte past the bracket never ran");

        let mut unmatched = vec![0, b'[', b'+', 0, 0, 0];
        let outcome = run_bounded(&mut unmatched, 100, OpSet::ALL, 6, 3);
        assert_eq!(outcome.halt, Halt::UnmatchedBracket);
        assert_eq!(unmatched[0], 0, "the byte past the bracket never ran");
    }

    /// A bound at the buffer's own cap is the symmetric substrate of §1.1 and must execute
    /// the identical instruction stream: confinement is the one thing a bound adds.
    #[test]
    fn a_bound_at_the_buffers_cap_runs_it_exactly_as_an_unbounded_run() {
        let program = vec![3, b'[', b'}', b'-', b']', b'.', b',', b'<', b'>', b'>', 0];
        let mut unbounded = program.clone();
        let mut bounded = program.clone();
        let len = program.len();
        assert_eq!(
            run_growing(&mut unbounded, 100, OpSet::ALL, len),
            run_bounded(&mut bounded, 100, OpSet::ALL, len, len)
        );
        assert_eq!(unbounded, bounded);
    }

    #[test]
    fn ops_are_the_ten_documented_bytes() {
        assert!(OPS.iter().all(|b| is_op(*b)));
        assert!(!is_op(b'a'));
        assert!(
            !is_op(STEAL),
            "the steal byte is not one of the ten BFF ops"
        );
        assert_eq!(OPS.len(), 10);
    }

    fn joined_bounds(cap: usize) -> Bounds {
        Bounds {
            max_steps: 100,
            enabled: OpSet::ALL,
            cap,
            code_len: cap,
        }
    }

    /// The steal op of §1.1: the interpreter counts it against the half of the pair whose
    /// bytes are executing — the first tape's code before the split, the second's after —
    /// and moves nothing itself, since what a steal is worth is the world's economy.
    #[test]
    fn a_steal_is_counted_against_the_half_of_the_pair_that_ran_it() {
        let joined = vec![STEAL, 0, 0, STEAL];
        let mut pair = joined.clone();
        let outcome = run_stealing(&mut pair, joined_bounds(4), Stealing::At(2));

        assert_eq!(outcome.steals, [1, 1]);
        assert_eq!(outcome.steps, 4, "a steal costs its step like any other op");
        assert_eq!(pair, joined, "a steal moves no byte of the pair");
    }

    /// Under a `host` interaction the pointer never leaves the first tape, so every steal
    /// an interaction executes is the host's.
    #[test]
    fn a_hosted_run_credits_every_steal_to_the_host() {
        let mut pair = vec![STEAL; 4];
        let outcome = run_stealing(
            &mut pair,
            Bounds {
                code_len: 2,
                ..joined_bounds(4)
            },
            Stealing::At(2),
        );

        assert_eq!(outcome.steals, [2, 0], "the partner's bytes never ran");
    }

    /// Off — every run at the defaults — the byte is not in the table the loop reads, so it
    /// is the plain no-op any other non-instruction byte is, down to the step it costs.
    #[test]
    fn the_steal_byte_is_a_no_op_until_a_run_switches_it_on() {
        let mut thieves = vec![STEAL; 4];
        let outcome = run_bounded(&mut thieves, 100, OpSet::ALL, 4, 4);
        assert_eq!(outcome.steals, [0, 0]);
        assert_eq!(thieves, vec![STEAL; 4]);

        let mut inert = vec![b'a'; 4];
        assert_eq!(run_bounded(&mut inert, 100, OpSet::ALL, 4, 4), outcome);
    }

    /// What `first_image` must read, found the slow way: run the pair under every budget
    /// from 0 up with `run_with` itself, and take the first that leaves an image.
    fn first_image_by_rerunning(pair: &[u8], source: &[u8], max_steps: u32) -> Option<Image> {
        let half = source.len();
        let reversed: Vec<u8> = source.iter().rev().copied().collect();
        (0..=max_steps).find_map(|budget| {
            let mut run = pair.to_vec();
            let outcome = run_with(&mut run, budget, OpSet::ALL);
            let partner = &run[half..];
            let orientation = match (partner == source, partner == reversed.as_slice()) {
                (true, true) => Orientation::Both,
                (true, false) => Orientation::Forward,
                (false, true) => Orientation::Reverse,
                (false, false) => return None,
            };
            Some(Image {
                steps: outcome.steps,
                orientation,
            })
        })
    }

    /// The watched run is `run_with` step for step: over random short pairs drawn mostly
    /// from the ten ops, it stops at the very step the interpreter itself first leaves an
    /// image, and leaves the buffer exactly as `run_with` does under that budget.
    #[test]
    fn the_first_image_is_the_step_the_interpreter_itself_first_leaves_one_at() {
        const ALPHABET: &[u8] = b"<>{}+-.,[]\0\0a";
        let mut rng = crate::rng::seeded(17, 0, 0);
        let mut images = 0;
        for _ in 0..20_000 {
            let half = 2 + crate::rng::below(&mut rng, 3) as usize;
            let pair: Vec<u8> = (0..2 * half)
                .map(|_| ALPHABET[crate::rng::below(&mut rng, ALPHABET.len() as u64) as usize])
                .collect();
            let source = pair[..half].to_vec();

            let mut watched = pair.clone();
            let read = first_image(&mut watched, &source, 60, OpSet::ALL);

            assert_eq!(
                read,
                first_image_by_rerunning(&pair, &source, 60),
                "{pair:?}"
            );
            let mut expected = pair.clone();
            run_with(
                &mut expected,
                read.map_or(60, |image| image.steps),
                OpSet::ALL,
            );
            assert_eq!(watched, expected, "{pair:?}");
            images += usize::from(read.is_some());
        }
        assert!(images > 100, "only {images} pairs ever held an image");
    }

    #[test]
    fn an_image_the_partner_already_holds_is_complete_before_the_first_step() {
        let mut pair = b"abab".to_vec();
        assert_eq!(
            first_image(&mut pair, b"ab", 100, OpSet::ALL),
            Some(Image {
                steps: 0,
                orientation: Orientation::Forward
            })
        );
    }

    /// `{` puts head1 on the pair's last byte and `.` writes the tape's first byte there,
    /// which completes the image at the second step; the source reads the same both ways.
    #[test]
    fn a_palindromes_image_lies_both_ways_round() {
        let mut pair = b"{..{{..z".to_vec();
        assert_eq!(
            first_image(&mut pair, b"{..{", 100, OpSet::ALL),
            Some(Image {
                steps: 2,
                orientation: Orientation::Both
            })
        );
    }

    #[test]
    fn a_pair_that_never_holds_an_image_reads_none() {
        let mut pair = b"+++aaaaa".to_vec();
        assert_eq!(first_image(&mut pair, b"+++a", 100, OpSet::ALL), None);
        assert_eq!(pair, b".++aaaaa", "the run went on to its end");
    }
}
