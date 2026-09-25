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
///
/// A run whose whole state recurs skips the whole periods of its cycle (`Recurrence`), and
/// a loop that goes round the same way lap after lap is replayed from its acting steps
/// alone (`Laps`): either way the run ends with the buffer, halt, step count and steals a
/// run of every step ends with.
pub fn run_stealing(tape: &mut Vec<u8>, bounds: Bounds, stealing: Stealing) -> Outcome {
    #[cfg(test)]
    if !SKIPPING.get() {
        return execute::<false>(tape, bounds, stealing);
    }
    execute::<true>(tape, bounds, stealing)
}

#[cfg(test)]
thread_local! {
    /// Off, `run_stealing` executes every step: the reference the equivalence tests hold
    /// the skips to, down to whole worlds stepped through `World::step`.
    pub(crate) static SKIPPING: std::cell::Cell<bool> = const { std::cell::Cell::new(true) };
    /// How many steps each skip has added without running them, so a test can tell an
    /// equivalence that held because the skip was exact from one where it never fired.
    pub(crate) static RECURRED: std::cell::Cell<u64> = const { std::cell::Cell::new(0) };
    pub(crate) static LAPPED: std::cell::Cell<u64> = const { std::cell::Cell::new(0) };
}

/// The interpreter loop. `SKIP` compiles both skips in or out; out, it is the plain loop
/// that executes every step, which the tests keep as the reference.
fn execute<const SKIP: bool>(tape: &mut Vec<u8>, bounds: Bounds, stealing: Stealing) -> Outcome {
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
    let mut recurrence = Recurrence::new();
    let mut laps = Laps::default();
    // Whether any byte of the buffer, or its length, has changed since the last jump back,
    // and where that jump landed.
    let mut changed = true;
    let mut last_target = usize::MAX;

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
                let before = len;
                head0 = step_right(head0, &mut len, cap, tape);
                changed |= len != before;
                bound = len.min(code_len);
            }
            HEAD1_LEFT => head1 = (head1 + len - 1) % len,
            HEAD1_RIGHT => {
                let before = len;
                head1 = step_right(head1, &mut len, cap, tape);
                changed |= len != before;
                bound = len.min(code_len);
            }
            INC => {
                tape[head0] = tape[head0].wrapping_add(1);
                changed = true;
            }
            DEC => {
                tape[head0] = tape[head0].wrapping_sub(1);
                changed = true;
            }
            COPY_TO_HEAD1 => {
                let byte = tape[head0];
                changed |= tape[head1] != byte;
                tape[head1] = byte;
            }
            COPY_TO_HEAD0 => {
                let byte = tape[head1];
                changed |= tape[head0] != byte;
                tape[head0] = byte;
            }
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
                Some(target) => {
                    ip = target;
                    if SKIP {
                        let idle = !std::mem::take(&mut changed);
                        let mut machine = Machine {
                            ip,
                            head0,
                            head1,
                            steps,
                            steals,
                        };
                        recurrence.observe(&mut machine, idle, max_steps);
                        if ip == last_target && len == cap {
                            let frame = Frame {
                                enabled: &enabled,
                                len,
                                bound,
                                split,
                                max_steps,
                            };
                            changed = laps.run(tape, &frame, &mut machine);
                        }
                        last_target = ip;
                        Machine {
                            ip,
                            head0,
                            head1,
                            steps,
                            steals,
                        } = machine;
                    }
                }
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

/// An execution's state besides its buffer: where the pointer and both heads stand, and
/// the steps and steals it has taken.
#[derive(Debug, Clone, Copy)]
struct Machine {
    ip: usize,
    head0: usize,
    head1: usize,
    steps: u32,
    steals: [u32; 2],
}

impl Machine {
    fn place(&self) -> (usize, usize, usize) {
        (self.ip, self.head0, self.head1)
    }

    /// Adds `times` repeats of the steps and steals one stretch from `earlier` to here
    /// took, and says how many steps that was.
    fn repeat(&mut self, earlier: &Machine, times: u32) -> u32 {
        let added = times * (self.steps - earlier.steps);
        self.steps += added;
        for half in 0..2 {
            self.steals[half] += times * (self.steals[half] - earlier.steals[half]);
        }
        added
    }
}

/// What one execution holds fixed once its buffer is at its cap: the table of enabled
/// ops, the buffer's length and the pointer's bound, where the pair was joined, and the
/// budget.
struct Frame<'a> {
    enabled: &'a [bool; 256],
    len: usize,
    bound: usize,
    split: usize,
    max_steps: u32,
}

/// Recognises an execution whose whole state has recurred: a loop that has stopped
/// changing its buffer and brought its heads back to where they stood.
///
/// The state is the buffer, the pointer and the two heads; nothing else in the loop moves
/// but the steps and steals it counts. It is read at every jump back, because a pointer
/// that never jumps back only ever moves forward and cannot come round again. Two jumps
/// back with the same pointer and heads, and no byte of the buffer nor its length changed
/// in between, are the same state, and everything after the later one repeats what came
/// after the earlier one, period for period. So the run may add whole periods of steps at
/// once — and each period's steals, the same every time round — and step out the
/// remainder, and it ends exactly where a run of every step ends.
///
/// Two earlier states are kept to compare against, each an O(1) comparison per jump: the
/// first jump back after the buffer last changed, which catches a copier the moment its
/// heads have gone once round, since their stride makes every such cycle close on itself;
/// and a probe moved to the latest jump at every power of two (Brent's cycle finding), which
/// catches a cycle entered only after a run-in, once the power reaches its length.
#[derive(Debug)]
struct Recurrence {
    anchor: Option<Machine>,
    probe: Option<Machine>,
    power: u64,
    lap: u64,
    spent: bool,
}

impl Recurrence {
    fn new() -> Self {
        Self {
            anchor: None,
            probe: None,
            power: 1,
            lap: 0,
            spent: false,
        }
    }

    /// Reads the state at one jump back, `idle` saying whether the buffer held still since
    /// the one before, and once the state has recurred adds every whole period the budget
    /// still holds. Skips once: what is left afterwards is shorter than a period.
    fn observe(&mut self, at: &mut Machine, idle: bool, max_steps: u32) {
        if self.spent {
            return;
        }
        if !idle {
            self.anchor = Some(*at);
            self.probe = Some(*at);
            self.power = 1;
            self.lap = 0;
            return;
        }
        for earlier in [self.anchor, self.probe].into_iter().flatten() {
            if earlier.place() == at.place() {
                self.spent = true;
                let periods = (max_steps - at.steps) / (at.steps - earlier.steps);
                tally(Skip::Recurred, at.repeat(&earlier, periods));
                return;
            }
        }
        self.lap += 1;
        if self.lap == self.power {
            self.probe = Some(*at);
            self.power *= 2;
            self.lap = 0;
        }
    }
}

/// What one step of a lap did that depended on the buffer or changed it: a bracket that
/// found the byte under head0 zero or not, a copy between the heads, or an increment or
/// decrement under head0. Head moves, no-ops and steals are not here: they only move the
/// heads and count, which the offsets and counts of the next such step already hold.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Act {
    Zero,
    NonZero,
    ToHead1,
    ToHead0,
    Inc,
    Dec,
}

/// One acting step of a lap, and where the lap stood as it took it: the pointer, the
/// steps and steals taken since the lap began, and each head's offset from where it began.
#[derive(Debug, Clone, Copy)]
struct Beat {
    act: Act,
    ip: usize,
    steps: u32,
    steals: [u32; 2],
    head0: usize,
    head1: usize,
}

/// The laps no whole cycle covers. An emerged world's copier loop is tens of bytes of
/// code, so its heads take more steps to come round than any budget allows and its state
/// never recurs; yet every lap does the same few things — a copy, a few head moves, a
/// bracket — a byte further on, over tens of no-op bytes.
///
/// A loop that has closed one lap on a bracket and comes back to it runs its next lap
/// here, faithfully and one step at a time, noting each acting step (`Beat`) with the
/// heads as offsets from where the lap began. The pointer then stands where it began and
/// the heads have moved by a fixed shift. The next lap, from any heads, is those beats
/// again at the shifted heads, in order: as long as every bracket reads the way it did,
/// the same code sends the pointer the same way, through the same no-ops, steals and head
/// moves. So each beat's bracket is tested and each write made, in order, on the buffer
/// itself, and the rest of the lap is counted rather than run.
///
/// Two things stop a lap, just before the beat concerned, where the interpreter takes up
/// the run itself: a bracket reading the other way, and a write that would change a byte of
/// the code the lap runs through — the bytes from the lowest its pointer reached to the
/// furthest, which also hold every bracket the lap matched. A lap that changed its own code as it was
/// noted is not repeated at all. A lap is only begun whole within the budget, and only on a
/// buffer at its cap, where a head stepping off the end wraps as every other step does
/// rather than claiming a byte.
#[derive(Default)]
struct Laps {
    beats: Vec<Beat>,
}

impl Laps {
    /// More acting steps than this and a lap is not worth noting; it runs step by step.
    const MOST_BEATS: usize = 64;

    /// Runs the laps from `at`, the pointer on the bracket the last one closed on, and
    /// says whether they changed the buffer.
    fn run(&mut self, tape: &mut [u8], frame: &Frame, at: &mut Machine) -> bool {
        let begun = *at;
        let mut changed = false;
        let Some(code) = self.note(tape, frame, at, &mut changed) else {
            return changed;
        };
        let len = frame.len;
        let shift0 = (at.head0 + len - begun.head0) % len;
        let shift1 = (at.head1 + len - begun.head1) % len;
        let lap_steps = at.steps - begun.steps;
        let lap_steals = [
            at.steals[0] - begun.steals[0],
            at.steals[1] - begun.steals[1],
        ];
        let mut repeated = 0u32;
        while frame.max_steps - at.steps >= lap_steps {
            let from = *at;
            for beat in &self.beats {
                let head0 = (from.head0 + beat.head0) % len;
                let head1 = (from.head1 + beat.head1) % len;
                let write = match beat.act {
                    Act::Zero | Act::NonZero => None,
                    Act::ToHead1 => Some((head1, tape[head0])),
                    Act::ToHead0 => Some((head0, tape[head1])),
                    Act::Inc => Some((head0, tape[head0].wrapping_add(1))),
                    Act::Dec => Some((head0, tape[head0].wrapping_sub(1))),
                };
                let holds = match write {
                    None => (tape[head0] == 0) == (beat.act == Act::Zero),
                    Some((to, byte)) => tape[to] == byte || !code.contains(&to),
                };
                if holds {
                    if let Some((to, byte)) = write {
                        changed |= tape[to] != byte;
                        tape[to] = byte;
                    }
                    continue;
                }
                *at = Machine {
                    ip: beat.ip - 1,
                    head0,
                    head1,
                    steps: from.steps + beat.steps,
                    steals: [
                        from.steals[0] + beat.steals[0],
                        from.steals[1] + beat.steals[1],
                    ],
                };
                tally(Skip::Lapped, repeated + beat.steps);
                return changed;
            }
            at.head0 = (from.head0 + shift0) % len;
            at.head1 = (from.head1 + shift1) % len;
            at.steps += lap_steps;
            at.steals = [
                from.steals[0] + lap_steals[0],
                from.steals[1] + lap_steals[1],
            ];
            repeated += lap_steps;
        }
        tally(Skip::Lapped, repeated);
        changed
    }

    /// Runs one lap from `at`, the pointer on the bracket it began from, noting its beats.
    /// The code it ran through once it closes back on that bracket, without having changed
    /// any of it; `None` where it stopped short, before the step the interpreter must take
    /// itself, with `at` where it stopped, or where it rewrote its own code.
    fn note(
        &mut self,
        tape: &mut [u8],
        frame: &Frame,
        at: &mut Machine,
        changed: &mut bool,
    ) -> Option<std::ops::RangeInclusive<usize>> {
        let Frame {
            enabled,
            len,
            bound,
            split,
            max_steps,
        } = *frame;
        let begun = *at;
        let (mut lowest, mut furthest) = (begun.ip, begun.ip);
        let mut rewrote: Vec<usize> = Vec::new();
        self.beats.clear();
        loop {
            let ip = at.ip + 1;
            if ip >= bound || at.steps == max_steps || self.beats.len() == Self::MOST_BEATS {
                return None;
            }
            let beat = |act| Beat {
                act,
                ip,
                steps: at.steps - begun.steps,
                steals: [
                    at.steals[0] - begun.steals[0],
                    at.steals[1] - begun.steals[1],
                ],
                head0: (at.head0 + len - begun.head0) % len,
                head1: (at.head1 + len - begun.head1) % len,
            };
            let mut next = ip;
            let mut write = None;
            match tape[ip] {
                byte if !enabled[byte as usize] => {}
                HEAD0_LEFT => at.head0 = (at.head0 + len - 1) % len,
                HEAD0_RIGHT => at.head0 = (at.head0 + 1) % len,
                HEAD1_LEFT => at.head1 = (at.head1 + len - 1) % len,
                HEAD1_RIGHT => at.head1 = (at.head1 + 1) % len,
                INC => {
                    self.beats.push(beat(Act::Inc));
                    write = Some((at.head0, tape[at.head0].wrapping_add(1)));
                }
                DEC => {
                    self.beats.push(beat(Act::Dec));
                    write = Some((at.head0, tape[at.head0].wrapping_sub(1)));
                }
                COPY_TO_HEAD1 => {
                    self.beats.push(beat(Act::ToHead1));
                    write = Some((at.head1, tape[at.head0]));
                }
                COPY_TO_HEAD0 => {
                    self.beats.push(beat(Act::ToHead0));
                    write = Some((at.head0, tape[at.head1]));
                }
                STEAL => at.steals[usize::from(ip >= split)] += 1,
                LOOP_START if tape[at.head0] == 0 => {
                    self.beats.push(beat(Act::Zero));
                    next = match_forward(tape, ip)?;
                }
                LOOP_START => self.beats.push(beat(Act::NonZero)),
                LOOP_END if tape[at.head0] != 0 => {
                    self.beats.push(beat(Act::NonZero));
                    next = match_backward(tape, ip)?;
                }
                LOOP_END => self.beats.push(beat(Act::Zero)),
                _ => {}
            }
            if let Some((to, byte)) = write {
                if tape[to] != byte {
                    *changed = true;
                    rewrote.push(to);
                }
                tape[to] = byte;
            }
            at.steps += 1;
            at.ip = next;
            lowest = lowest.min(next);
            furthest = furthest.max(ip).max(next);
            if next == begun.ip {
                let code = lowest..=furthest;
                return (!rewrote.iter().any(|to| code.contains(to))).then_some(code);
            }
        }
    }
}

/// Which skip added steps without running them, for the tests' tallies.
#[derive(Debug, Clone, Copy)]
enum Skip {
    Recurred,
    Lapped,
}

#[cfg(test)]
fn tally(skip: Skip, steps: u32) {
    let counter = match skip {
        Skip::Recurred => &RECURRED,
        Skip::Lapped => &LAPPED,
    };
    counter.set(counter.get() + u64::from(steps));
}

#[cfg(not(test))]
fn tally(_skip: Skip, _steps: u32) {}

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

    /// A run's whole result under the skip, beside the plain loop's: the buffer, and the
    /// halt, steps and steals of the outcome.
    fn both_ways(pair: &[u8], bounds: Bounds, stealing: Stealing) -> [(Vec<u8>, Outcome); 2] {
        let mut skipped = pair.to_vec();
        let with_skip = execute::<true>(&mut skipped, bounds, stealing);
        let mut stepped = pair.to_vec();
        let every_step = execute::<false>(&mut stepped, bounds, stealing);
        [(skipped, with_skip), (stepped, every_step)]
    }

    fn assert_skips_exactly(pair: &[u8], bounds: Bounds, stealing: Stealing) {
        let [skipped, stepped] = both_ways(pair, bounds, stealing);
        assert_eq!(skipped, stepped, "{pair:?} under {bounds:?}, {stealing:?}");
    }

    /// The steps each skip added while `run` ran: `(recurred, lapped)`.
    fn skipped_during(run: impl FnOnce()) -> (u64, u64) {
        let before = (RECURRED.get(), LAPPED.get());
        run();
        (RECURRED.get() - before.0, LAPPED.get() - before.1)
    }

    /// Both skips are exact: over random pairs of every length from 2 to 64, drawn mostly
    /// from the ops and the steal byte so that loops form and close, under random budgets,
    /// with and without room to grow, joined or hosted, stealing on or off, the run that
    /// skips ends with the buffer, halt, steps and steals of the run that executes every
    /// step.
    #[test]
    fn skipping_ends_every_run_where_executing_every_step_does() {
        const ALPHABET: &[u8] = b"<>{}+-.,[][]]]$$\0\x01a";
        let mut rng = crate::rng::seeded(29, 0, 0);
        let mut draw = |bound: u64| crate::rng::below(&mut rng, bound) as usize;
        let (recurred, lapped) = skipped_during(|| {
            for _ in 0..200_000 {
                let len = 2 + draw(63);
                let split = 1 + draw(len as u64 - 1);
                let pair: Vec<u8> = (0..len)
                    .map(|_| ALPHABET[draw(ALPHABET.len() as u64)])
                    .collect();
                let cap = len + [0, 0, 1, draw(40)][draw(4)];
                let bounds = Bounds {
                    max_steps: [draw(64), draw(1_024), draw(8_193)][draw(3)] as u32,
                    enabled: if draw(4) == 0 {
                        OpSet::parse("<>{}.[]").expect("a legal set")
                    } else {
                        OpSet::ALL
                    },
                    cap,
                    code_len: if draw(2) == 0 { split } else { cap },
                };
                let stealing = if draw(2) == 0 {
                    Stealing::Off
                } else {
                    Stealing::At(split)
                };
                assert_skips_exactly(&pair, bounds, stealing);
            }
        });
        assert!(
            recurred > 10_000_000,
            "cycles skipped only {recurred} steps"
        );
        assert!(lapped > 1_000_000, "laps skipped only {lapped} steps");
    }

    /// The lap skip against the paths a lap can take: short programs dense in brackets and
    /// head moves, and no increments, over data that is mostly nonzero with a zero here and
    /// there, so nested loops run for a while and then leave by a different bracket than
    /// the lap that was noted. Each run must end where the run of every step does.
    #[test]
    fn a_lap_that_would_leave_by_another_bracket_is_never_skipped() {
        const CODE: &[u8] = b"[[[]]]]<<>>>{}}..,$a";
        const DATA: &[u8] = b"\0\x01\x01\x01\x02a[]";
        let mut rng = crate::rng::seeded(31, 0, 0);
        let mut draw = |bound: u64| crate::rng::below(&mut rng, bound) as usize;
        let (_, lapped) = skipped_during(|| {
            for _ in 0..200_000 {
                let code_len = 3 + draw(14);
                let len = code_len + 2 + draw(48);
                let pair: Vec<u8> = (0..len)
                    .map(|at| match at < code_len {
                        true => CODE[draw(CODE.len() as u64)],
                        false => DATA[draw(DATA.len() as u64)],
                    })
                    .collect();
                let split = 1 + draw(len as u64 - 1);
                let max_steps = [draw(256), draw(4_096)][draw(2)] as u32;
                let stealing = [Stealing::Off, Stealing::At(split)][draw(2)];
                assert_skips_exactly(&pair, joined(max_steps, len), stealing);
            }
        });
        assert!(lapped > 1_000_000, "laps skipped only {lapped} steps");
    }

    /// A lap through an inner loop, `[>]` inside `[> … >]`, over data laid out so that
    /// every lap takes one path: the inner `[` entered and its `]` falling through, or the
    /// inner `[` jumping straight past its body. Where the data changes step, the inner
    /// bracket reads a byte the noted lap did not, and the lap takes another path from
    /// there on. The loops only read, so the `+` after them marks where head0 stopped, and
    /// every budget is tried: the run is held to the plain loop at every step.
    #[test]
    fn a_lap_whose_inner_loop_changes_course_is_run_from_there() {
        let entered = [1u8, 1, 0];
        let jumped = [1u8, 0];
        let courses: [(&[u8], &[u8]); 3] = [
            (&entered, &[1, 0, 0, 1]),
            (&entered, &[1, 1, 1, 1, 1, 1, 1, 0]),
            (&jumped, &[1, 1, 1, 1, 1, 0]),
        ];
        for (lap, change) in courses {
            let mut data = lap.repeat(12);
            data.extend_from_slice(change);
            data.extend(lap.repeat(4));
            data.extend([0; 4]);
            let mut pair = vec![HEAD0_LEFT; data.len()];
            pair.extend_from_slice(b"[>[>]>]+");
            pair.extend_from_slice(&data);
            let (_, lapped) = skipped_during(|| {
                for max_steps in 0..=600 {
                    assert_skips_exactly(&pair, joined(max_steps, pair.len()), Stealing::Off);
                }
            });
            assert!(lapped > 0, "the laps before {change:?} were all run");
        }
    }

    /// The copier of an emerged world (#245): `{` puts head1 on the pair's last byte, and
    /// the loop copies head0 onto it with head0 walking right and head1 left, over `pad`
    /// non-op bytes after each op. No byte is zero, so the loop never ends; once the pair is
    /// a palindrome every lap rewrites a byte with itself, and the pair returns to itself
    /// every lap of the heads.
    fn reverse_copier(len: usize, partner_len: usize, pad: usize, seed: u64) -> Vec<u8> {
        let mut rng = crate::rng::seeded(seed, 0, 0);
        let mut filler = || loop {
            let byte = 1 + crate::rng::below(&mut rng, 255) as u8;
            if !is_op(byte) {
                return byte;
            }
        };
        let mut pair = Vec::new();
        for op in b"{[.<>>{]" {
            pair.push(*op);
            pair.extend((0..pad).map(|_| filler()));
        }
        pair.extend((pair.len()..len).map(|_| filler()));
        pair.extend((0..partner_len).map(|_| filler()));
        pair
    }

    fn joined(max_steps: u32, cap: usize) -> Bounds {
        Bounds {
            max_steps,
            enabled: OpSet::ALL,
            cap,
            code_len: cap,
        }
    }

    /// At every length an emerged world holds, with a partner of the same length or a
    /// ragged one, joined or hosted, the copier skips its idle laps and ends where running
    /// them ends. With room to grow, a head walking off the end claims a zero byte that
    /// ends the loop, and the run that follows must still come out the same.
    #[test]
    fn a_reverse_copier_skips_its_laps_and_ends_where_every_step_ends() {
        for len in [64, 128, 256] {
            for partner_len in [len, len / 2 + 3, len - 1] {
                for pad in [0, 4] {
                    let seed = (len + partner_len + pad) as u64;
                    let pair = reverse_copier(len, partner_len, pad, seed);
                    for cap in [pair.len(), pair.len() + 17, len + len + 40] {
                        let (recurred, lapped) = skipped_during(|| {
                            assert_skips_exactly(&pair, joined(8_192, cap), Stealing::Off);
                            assert_skips_exactly(
                                &pair,
                                Bounds {
                                    code_len: len,
                                    ..joined(8_192, cap)
                                },
                                Stealing::At(len),
                            );
                        });
                        // A 256-byte copier over a padded loop spends the whole budget
                        // on its first pass.
                        if cap == pair.len() && (pad == 0 || len == 64) {
                            assert!(
                                recurred + lapped > 2_048,
                                "a copier at {len}+{partner_len} ran its laps"
                            );
                        }
                    }
                }
            }
        }
    }

    /// The emerged copier's loop is tens of bytes (#245), so its heads come round in more
    /// steps than the budget: its state never recurs and only the lap skip applies. Once
    /// the partner half is the reversed tape, most of the budget is idle laps.
    #[test]
    fn a_copier_too_slow_to_come_round_still_skips_its_idle_laps() {
        for len in [64, 128] {
            let pair = reverse_copier(len, len, 5, len as u64);
            let (recurred, lapped) = skipped_during(|| {
                assert_skips_exactly(&pair, joined(8_192, 2 * len), Stealing::Off);
            });
            assert_eq!(recurred, 0, "the heads never came round at {len}");
            assert!(lapped > 2_048, "only {lapped} steps of idle laps at {len}");
        }
    }

    /// A copier whose heads walk the same way a fixed gap apart: `}` puts head1 that far
    /// ahead of head0, and the loop pulls each byte back by the gap. The pair repeats at the
    /// gap past the moves, so one lap writes the pattern over them and the pair then holds
    /// still for ever, with a steal in the loop that every lap counts again: the skipped
    /// laps' steals are counted too.
    #[test]
    fn a_forward_copier_skips_its_laps_and_counts_their_steals() {
        for gap in [6, 8, 13] {
            let mut pattern = b"[,$>}]".to_vec();
            pattern.resize(gap, b'a');
            let mut pair = vec![b'}'; gap];
            for _ in 0..96 / gap {
                pair.extend_from_slice(&pattern);
            }
            let bounds = joined(8_192, pair.len());
            let (recurred, lapped) = skipped_during(|| {
                let [skipped, stepped] = both_ways(&pair, bounds, Stealing::At(pair.len() / 2));
                assert!(stepped.1.steals[0] > 1_000, "the loop steals every lap");
                assert_eq!(skipped, stepped);
            });
            assert!(
                recurred + lapped > 4_096,
                "a forward copier with a gap of {gap} ran its laps"
            );
        }
    }

    /// With room to grow the lap skip stands aside, since a head stepping off the end may
    /// claim a byte on one lap and not the last; a loop whose heads come straight back is
    /// still a cycle, and the cycle skip takes it.
    #[test]
    fn a_cycle_is_skipped_where_the_buffer_may_still_grow() {
        let pair = vec![1, b'[', b'}', b'{', b']'];
        let (recurred, lapped) = skipped_during(|| {
            assert_skips_exactly(&pair, joined(8_192, 9), Stealing::Off);
        });
        assert!(recurred > 8_000);
        assert_eq!(lapped, 0);
    }

    /// The skip lands on the very step budget: a cycle whose period divides what is left
    /// skips all of it, and one a step longer steps out the remainder.
    #[test]
    fn a_skip_lands_on_the_budget_whatever_is_left_over() {
        let pair = vec![1, b'[', b'>', b'<', b']'];
        for max_steps in 60..=80 {
            let [skipped, stepped] = both_ways(&pair, joined(max_steps, 5), Stealing::Off);
            assert_eq!(skipped, stepped);
            assert_eq!(skipped.1.steps, max_steps);
            assert_eq!(skipped.1.halt, Halt::StepLimit);
        }
    }

    /// A loop whose heads return to the same bytes while the buffer still changes is
    /// neither a cycle nor an idle lap: an increment each lap keeps the state new until the
    /// byte wraps to zero.
    #[test]
    fn a_loop_that_keeps_writing_is_never_skipped() {
        let pair = vec![b'[', b'+', b']', 0];
        let skipped = skipped_during(|| {
            assert_skips_exactly(&[1, b'[', b'-', b']'], joined(8_192, 4), Stealing::Off);
            assert_skips_exactly(&pair, joined(8_192, 4), Stealing::Off);
        });
        assert_eq!(skipped, (0, 0));
    }
}
