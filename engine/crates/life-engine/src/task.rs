//! The task assay (`docs/DESIGN.md` §1.1, "Tasks and the emit op"; the 2026-10-01 design
//! record entry on the task assay): a tape run alone on two small inputs, with the emit
//! byte as an instruction, and credited with every arithmetic task one of its output slots
//! computes in every case. The verdict is a pure function of the tape, the cases and the
//! run's instruction set, so the world computes it once per distinct tape and cell order
//! cannot matter.

use crate::bff::{self, AssayOps, Bounds, Emitted, OpSet};
use crate::rng::{self, Rng};
use std::collections::HashMap;

/// The steps one case may run. MUL's minimal program needs about 3 530 on the largest
/// inputs, and it is the task that sets the budget.
pub const TASK_STEPS: u32 = 4096;
/// Cases per assay: every case must agree for a task to be credited.
pub const TASK_CASES: usize = 3;
/// The most outputs one case may emit before it stops; a task may be credited on any slot.
pub const TASK_MAX_OUTPUTS: usize = 4;
/// Both inputs are drawn uniformly below this, as 2607.09211 draws its inputs: a small
/// domain keeps loops over an input bounded. A draw holding a 0 is redrawn (`separates`).
pub const TASK_INPUT_RANGE: u8 = 16;
/// The most case draws one assay epoch makes before it falls back to `FALLBACK_CASES`.
/// About 68% of draws fail to separate, so the bound is never reached in practice; it is
/// there so the draw is total and deterministic.
pub const TASK_CASE_DRAWS: u32 = 1024;

/// One rung of the task ladder: its name, the energy units it is worth per assay, and the
/// byte it expects from inputs `x` and `y`, mod 256.
#[derive(Debug, Clone, Copy)]
pub struct Task {
    pub name: &'static str,
    pub units: u32,
    expect: fn(u8, u8) -> u8,
}

impl Task {
    pub fn expected(&self, x: u8, y: u8) -> u8 {
        (self.expect)(x, y)
    }

    /// Whether this task is one input plus `offset` on every input, x for `Input::X` and
    /// y for `Input::Y`: ECHO, INC and DEC are x plus 0, 1 and 255.
    fn is_offset_of(&self, input: Input, offset: u8) -> bool {
        (0..TASK_INPUT_RANGE).all(|x| {
            (0..TASK_INPUT_RANGE)
                .all(|y| self.expected(x, y) == input.of(x, y).wrapping_add(offset))
        })
    }
}

#[derive(Debug, Clone, Copy)]
enum Input {
    X,
    Y,
}

impl Input {
    fn of(self, x: u8, y: u8) -> u8 {
        match self {
            Self::X => x,
            Self::Y => y,
        }
    }
}

/// Cells drawn, uniformly with replacement, for the task shares of a sample: as many as
/// `replicator_share` draws, so a share moves in the same 1/256 steps.
pub const TASK_SAMPLE_CELLS: u32 = 256;
/// A task is a capability of the world when at least one sampled cell in this many is
/// credited with it: a share of 1/10, which is 26 of 256 compared as integers.
pub const TASK_CAPABILITY_DENOMINATOR: u32 = 10;
/// The first entry of `TASKS` whose minimal program needs a loop: ADD, SUB, NOT, DOUBLE and
/// MUL each move one input across in a `[...]`, where ECHO, INC and DEC are straight lines.
pub const FIRST_LOOP_TASK: usize = 3;

/// The arithmetic ladder, units doubling with difficulty as Avida's 2^n merits do. The
/// order is the bit order of a `Credit`.
pub const TASKS: [Task; 8] = [
    Task {
        name: "echo",
        units: 1,
        expect: |x, _| x,
    },
    Task {
        name: "inc",
        units: 2,
        expect: |x, _| x.wrapping_add(1),
    },
    Task {
        name: "dec",
        units: 2,
        expect: |x, _| x.wrapping_sub(1),
    },
    Task {
        name: "add",
        units: 4,
        expect: |x, y| x.wrapping_add(y),
    },
    Task {
        name: "sub",
        units: 4,
        expect: |x, y| x.wrapping_sub(y),
    },
    Task {
        name: "not",
        units: 8,
        expect: |x, _| 255 - x,
    },
    Task {
        name: "double",
        units: 8,
        expect: |x, _| x.wrapping_mul(2),
    },
    Task {
        name: "mul",
        units: 16,
        expect: |x, y| x.wrapping_mul(y),
    },
];

/// A set of cases that separates the ladder, used only if `TASK_CASE_DRAWS` draws in a row
/// all failed to.
const FALLBACK_CASES: [(u8, u8); TASK_CASES] = [(3, 5), (7, 2), (12, 9)];

/// The `(x, y)` inputs of one assay epoch, shared by every cell.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Cases([(u8, u8); TASK_CASES]);

impl Cases {
    /// Draws cases until they separate the tasks (`separates`), from `rng` only. Without
    /// the rule a tape that echoes x is credited ADD and SUB whenever y is 0 in every case,
    /// and MUL whenever it is 1 — the pilot's false credits.
    pub fn draw(rng: &mut Rng) -> Self {
        for _ in 0..TASK_CASE_DRAWS {
            let cases = Self(std::array::from_fn(|_| {
                let x = rng::below(rng, u64::from(TASK_INPUT_RANGE)) as u8;
                let y = rng::below(rng, u64::from(TASK_INPUT_RANGE)) as u8;
                (x, y)
            }));
            if cases.separates() {
                return cases;
            }
        }
        Self(FALLBACK_CASES)
    }

    pub fn new(cases: [(u8, u8); TASK_CASES]) -> Self {
        Self(cases)
    }

    pub fn inputs(&self) -> &[(u8, u8); TASK_CASES] {
        &self.0
    }

    /// Whether no constant, no wrong task and no cheap function of the inputs can pass:
    ///
    /// - within each task the expected outputs are pairwise distinct, so no constant can;
    /// - no two tasks expect the same outputs, so one output slot matches at most one task;
    /// - the x values are pairwise distinct and so are the y values, so no input is held
    ///   constant for another task to absorb: x+3 is ADD wherever y is 3 in every case;
    /// - no task's outputs sit a constant offset from x, or from y, unless the task is that
    ///   offset everywhere, so an input plus a constant, the cheapest thing a tape can
    ///   emit, earns only the task it is: y+1 is DOUBLE wherever y = 2x−1;
    /// - no input is 0, the value BFF's only branch tests, so no case can be told apart by
    ///   a zero test: `[<]>!` emits x where y is 0 and y elsewhere, which is SUB wherever
    ///   x = 2y in the other two cases.
    pub fn separates(&self) -> bool {
        let xs = self.0.map(|(x, _)| x);
        let ys = self.0.map(|(_, y)| y);
        if xs.contains(&0) || ys.contains(&0) || !distinct(&xs) || !distinct(&ys) {
            return false;
        }
        let expected: Vec<[u8; TASK_CASES]> =
            TASKS.iter().map(|task| self.expected(task)).collect();
        let distinct_within = expected.iter().all(distinct);
        let distinct_across = (1..expected.len()).all(|t| !expected[..t].contains(&expected[t]));
        let offsets_are_tasks = TASKS.iter().zip(&expected).all(|(task, outputs)| {
            [(Input::X, xs), (Input::Y, ys)]
                .into_iter()
                .all(|(input, values)| {
                    let offsets: [u8; TASK_CASES] =
                        std::array::from_fn(|case| outputs[case].wrapping_sub(values[case]));
                    !offsets.iter().all(|offset| *offset == offsets[0])
                        || task.is_offset_of(input, offsets[0])
                })
        });
        distinct_within && distinct_across && offsets_are_tasks
    }

    fn expected(&self, task: &Task) -> [u8; TASK_CASES] {
        self.0.map(|(x, y)| task.expected(x, y))
    }
}

fn distinct(values: &[u8; TASK_CASES]) -> bool {
    (1..TASK_CASES).all(|j| !values[..j].contains(&values[j]))
}

/// The tasks one tape was credited with, a bit per entry of `TASKS`.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub struct Credit(u8);

impl Credit {
    pub fn bits(self) -> u8 {
        self.0
    }

    pub fn has(self, task: usize) -> bool {
        self.0 & (1 << task) != 0
    }

    pub fn count(self) -> u32 {
        self.0.count_ones()
    }

    /// The energy units the credited tasks are worth together.
    pub fn units(self) -> u32 {
        self.units_from(0)
    }

    /// The units of the credited tasks at index `floor` and above: what a run whose
    /// `task_floor` is that rung pays.
    pub fn units_from(self, floor: usize) -> u32 {
        TASKS
            .iter()
            .enumerate()
            .filter(|(index, _)| *index >= floor && self.has(*index))
            .map(|(_, task)| task.units)
            .sum()
    }
}

/// How many of `TASK_SAMPLE_CELLS` sampled cells each task was credited to: the read-side
/// tally of the task observables (`docs/DESIGN.md` §1.2).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct TaskTally([u32; TASKS.len()]);

impl TaskTally {
    pub fn add(&mut self, credit: Credit) {
        for (task, credited) in self.0.iter_mut().enumerate() {
            *credited += u32::from(credit.has(task));
        }
    }

    pub fn credited(&self, task: usize) -> u32 {
        self.0[task]
    }

    pub fn share(&self, task: usize) -> f64 {
        f64::from(self.0[task]) / f64::from(TASK_SAMPLE_CELLS)
    }

    /// How many tasks at least a tenth of the sampled cells are credited with.
    pub fn capability(&self) -> u32 {
        self.capable(0)
    }

    /// The same count over the tasks that need a loop.
    pub fn capability_loop(&self) -> u32 {
        self.capable(FIRST_LOOP_TASK)
    }

    fn capable(&self, from: usize) -> u32 {
        self.0[from..]
            .iter()
            .filter(|credited| **credited * TASK_CAPABILITY_DENOMINATOR >= TASK_SAMPLE_CELLS)
            .count() as u32
    }
}

/// What one case of the assay produced: the bytes emitted, in order, and the steps run.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CaseRun {
    pub outputs: Vec<u8>,
    pub steps: u32,
}

/// Runs `tape` alone on one case. The buffer is the tape's bytes and as many zeros again,
/// a fixed `2L` with no growth, both heads wrapping over all of it; `x` sits on the last
/// byte and `y` on the one before, where `<` and `<<` reach them from head0 and `{` from
/// head1. The run executes the run's own `ops`, with `EMIT` as an instruction and the steal
/// byte a no-op, and stops at the end of the buffer, on an unmatched bracket, after
/// `TASK_STEPS` steps or at the `TASK_MAX_OUTPUTS`-th emit.
pub fn run_case(tape: &[u8], x: u8, y: u8, ops: OpSet) -> CaseRun {
    run_case_on(tape, x, y, ops, AssayOps::Emit)
}

/// `run_case` on the machine `assay_ops` names: the arithmetic assay's, or the logic
/// assay's, where `bff::NAND` is an instruction too. The buffer is the same for both.
pub(crate) fn run_case_on(tape: &[u8], x: u8, y: u8, ops: OpSet, assay_ops: AssayOps) -> CaseRun {
    run_case_with(tape, &[x, y], ops, assay_ops)
}

/// `run_case_on` with any number of inputs, each one byte further left: `inputs[0]` on the
/// buffer's last byte, `inputs[1]` on the one before, and so on, the topless ladder's z and
/// w on `B[2L−3]` and `B[2L−4]`. A buffer shorter than the inputs holds none of them.
pub(crate) fn run_case_with(
    tape: &[u8],
    inputs: &[u8],
    ops: OpSet,
    assay_ops: AssayOps,
) -> CaseRun {
    let len = 2 * tape.len();
    let mut buffer = Vec::with_capacity(len);
    buffer.extend_from_slice(tape);
    buffer.resize(len, 0);
    if len >= inputs.len() {
        for (slot, value) in inputs.iter().enumerate() {
            buffer[len - 1 - slot] = *value;
        }
    }
    let mut emitted = Emitted {
        bytes: Vec::with_capacity(TASK_MAX_OUTPUTS),
        most: TASK_MAX_OUTPUTS,
    };
    let bounds = Bounds {
        max_steps: TASK_STEPS,
        enabled: ops,
        cap: len,
        code_len: len,
    };
    let outcome = bff::run_emitting(&mut buffer, bounds, &mut emitted, assay_ops);
    CaseRun {
        outputs: emitted.bytes,
        steps: outcome.steps,
    }
}

/// The tasks `tape` is credited with on `cases`: task t when some output slot j holds
/// t's expected byte in every case.
///
/// A tape holding no emit byte is credited nothing and never run. That is a rule, not a
/// shortcut: such a tape could still increment a byte to `!` where its pointer will reach
/// it, but the emit a tape is paid for must be one it carries. A case that emits nothing
/// ends the assay, which is exact: no slot can then agree across every case.
pub fn assay(tape: &[u8], cases: &Cases, ops: OpSet) -> Credit {
    let Some(runs) = case_outputs(tape, cases.inputs(), ops, AssayOps::Emit) else {
        return Credit::default();
    };
    let mut bits = 0u8;
    for (index, task) in TASKS.iter().enumerate() {
        bits |= u8::from(slot_holds(&runs, cases.expected(task))) << index;
    }
    Credit(bits)
}

/// What each case of `inputs` emitted, in order, on the machine `assay_ops` names. `None`
/// for a tape holding no emit byte, which is never run, and as soon as a case emits nothing,
/// since no slot can then hold a task in every case.
pub(crate) fn case_outputs(
    tape: &[u8],
    inputs: &[(u8, u8); TASK_CASES],
    ops: OpSet,
    assay_ops: AssayOps,
) -> Option<Vec<Vec<u8>>> {
    let pairs = inputs.map(|(x, y)| [x, y]);
    case_outputs_with(
        tape,
        &pairs.each_ref().map(|pair| pair.as_slice()),
        ops,
        assay_ops,
    )
}

/// `case_outputs` on any number of cases, each case's inputs placed as `run_case_with`
/// places them.
pub(crate) fn case_outputs_with(
    tape: &[u8],
    inputs: &[&[u8]],
    ops: OpSet,
    assay_ops: AssayOps,
) -> Option<Vec<Vec<u8>>> {
    if !tape.contains(&bff::EMIT) {
        return None;
    }
    let mut runs = Vec::with_capacity(inputs.len());
    for case in inputs {
        let run = run_case_with(tape, case, ops, assay_ops);
        if run.outputs.is_empty() {
            return None;
        }
        runs.push(run.outputs);
    }
    Some(runs)
}

/// Whether one output slot holds `expected`'s byte in every case.
pub(crate) fn slot_holds(runs: &[Vec<u8>], expected: [u8; TASK_CASES]) -> bool {
    (0..TASK_MAX_OUTPUTS).any(|slot| {
        runs.iter()
            .zip(expected)
            .all(|(outputs, byte)| outputs.get(slot) == Some(&byte))
    })
}

/// The assay of many tapes on one epoch's cases, each distinct tape run once.
pub struct Memo<'a> {
    cases: Cases,
    ops: OpSet,
    seen: HashMap<&'a [u8], Credit>,
}

impl<'a> Memo<'a> {
    pub fn new(cases: Cases, ops: OpSet) -> Self {
        Self {
            cases,
            ops,
            seen: HashMap::new(),
        }
    }

    pub fn credit(&mut self, tape: &'a [u8]) -> Credit {
        if !tape.contains(&bff::EMIT) {
            return Credit::default();
        }
        let (cases, ops) = (&self.cases, self.ops);
        *self
            .seen
            .entry(tape)
            .or_insert_with(|| assay(tape, cases, ops))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The minimal programs of the design study's ladder (§3.2), each ending with head0
    /// back on byte 0.
    const MINIMAL: [&[u8]; 8] = [
        b"<!>",
        b"<+!>",
        b"<-!>",
        b"<<[->+<]>!>",
        b"<<[->-<]>!>",
        b"<[-<<->>]<<-!>>>",
        b"<[-<<++>>]<<!>>>",
        b"<[-<[-<+<+>>]<<[->>+<<]>>>]<<!>>>",
    ];

    fn credit_on(tape: &[u8], cases: [(u8, u8); TASK_CASES]) -> Credit {
        assay(tape, &Cases::new(cases), OpSet::ALL)
    }

    /// Each minimal program computes its own task on its first output slot for every one
    /// of the 256 inputs, through the assay's own buffer and interpreter, and on separating
    /// cases is credited with its own task and no other. The pointer runs on past the
    /// program through the scratch bytes it wrote, so a product of 33 executes as a second
    /// emit: a later slot may hold more, and only the first is read here.
    #[test]
    fn each_minimal_program_computes_its_task_on_every_input_and_is_credited_alone() {
        for (index, (program, task)) in MINIMAL.iter().zip(&TASKS).enumerate() {
            for x in 0..TASK_INPUT_RANGE {
                for y in 0..TASK_INPUT_RANGE {
                    let run = run_case(program, x, y, OpSet::ALL);
                    assert_eq!(
                        run.outputs.first(),
                        Some(&task.expected(x, y)),
                        "{} on ({x}, {y})",
                        task.name
                    );
                }
            }
            let mut rng = rng::seeded(5, 0, index as u64);
            for _ in 0..2_000 {
                let cases = Cases::draw(&mut rng);
                let credit = assay(program, &cases, OpSet::ALL);
                assert_eq!(credit, Credit(1 << index), "{} on {cases:?}", task.name);
                assert_eq!(credit.units(), task.units);
            }
        }
    }

    #[test]
    fn the_ladder_is_worth_what_the_design_says() {
        let names: Vec<&str> = TASKS.iter().map(|task| task.name).collect();
        assert_eq!(
            names,
            ["echo", "inc", "dec", "add", "sub", "not", "double", "mul"]
        );
        let units: Vec<u32> = TASKS.iter().map(|task| task.units).collect();
        assert_eq!(units, [1, 2, 2, 4, 4, 8, 8, 16]);
        assert_eq!(Credit(0xff).units(), 45);
        assert_eq!(Credit(0b1001).units(), 5);
    }

    /// A program that solves two tasks on two slots is credited both, and its units add.
    #[test]
    fn credit_is_per_output_slot() {
        let both = b"<!+!>";
        let credit = credit_on(both, FALLBACK_CASES);
        assert_eq!(credit, Credit(0b11));
        assert_eq!(credit.units(), 3);
    }

    /// No copying can fake a credit: a pure copier emits nothing, a copier with a junk
    /// emit emits a byte of itself whatever the inputs, and a sprayer emits a constant in
    /// each slot.
    #[test]
    fn copiers_constants_and_sprayers_are_credited_nothing() {
        let mut copier = b"{[.<>>{]".to_vec();
        copier.resize(64, b'a');
        let mut junk_emit = b"{[.<!>>{]".to_vec();
        junk_emit.resize(64, b'a');
        let mut forward = b"}}}}[,>}!]".to_vec();
        forward.resize(64, 1);
        let mut rng = rng::seeded(3, 0, 0);
        for _ in 0..2_000 {
            let cases = Cases::draw(&mut rng);
            for tape in [
                &copier[..],
                &junk_emit,
                &forward,
                b"[!+]",
                b"+[!+]",
                b"!!!!",
                b"+!+!+!+!",
                b"<<<<!",
                b">!",
            ] {
                assert_eq!(
                    assay(tape, &cases, OpSet::ALL),
                    Credit::default(),
                    "{:?} on {cases:?}",
                    String::from_utf8_lossy(tape)
                );
            }
        }
    }

    /// The separating rule, over draws, read off the inputs and the ladder directly: no
    /// draw is returned that fails it, and the fallback passes it too.
    #[test]
    fn every_drawn_set_of_cases_separates_the_tasks() {
        let distinct = |values: [u8; TASK_CASES]| {
            values[0] != values[1] && values[1] != values[2] && values[0] != values[2]
        };
        let mut rng = rng::seeded(11, 0, 0);
        for _ in 0..100_000 {
            let cases = Cases::draw(&mut rng);
            assert!(cases.separates(), "{cases:?}");
            let inputs = *cases.inputs();
            assert!(inputs.iter().all(
                |(x, y)| (1..TASK_INPUT_RANGE).contains(x) && (1..TASK_INPUT_RANGE).contains(y)
            ));
            assert!(distinct(inputs.map(|(x, _)| x)), "{cases:?}");
            assert!(distinct(inputs.map(|(_, y)| y)), "{cases:?}");
            for (t, task) in TASKS.iter().enumerate() {
                let outputs = cases.expected(task);
                assert!(distinct(outputs), "{} on {cases:?}", task.name);
                assert!(
                    TASKS[..t]
                        .iter()
                        .all(|other| cases.expected(other) != outputs),
                    "{} on {cases:?}",
                    task.name
                );
            }
        }
        assert!(Cases::new(FALLBACK_CASES).separates());
    }

    /// The traps the rule closes, each on cases it refuses and where the cheap tape would
    /// be credited: an echo of x earns ADD on a constant y of 0 (the pilot's), x+3 earns
    /// ADD on a constant y of 3, y+1 earns DOUBLE where y = 2x−1, and the zero-test scan
    /// `[<]>!` earns SUB where one y is 0 and x = 2y in the other two cases.
    #[test]
    fn the_separating_rule_closes_each_trap_a_cheap_tape_springs() {
        let traps = [
            (&b"<!>"[..], [(3, 0), (5, 0), (9, 0)], 3),
            (&b"<+++!"[..], [(2, 3), (5, 3), (9, 3)], 3),
            (&b"<<+!"[..], [(4, 7), (3, 5), (5, 9)], 6),
            (&b"[<]>!"[..], [(6, 3), (11, 0), (14, 7)], 4),
        ];
        for (tape, inputs, task) in traps {
            let cases = Cases::new(inputs);
            assert!(!cases.separates(), "{inputs:?}");
            let credit = assay(tape, &cases, OpSet::ALL);
            assert!(
                credit.has(task),
                "{} would earn {} on {inputs:?}: {credit:?}",
                String::from_utf8_lossy(tape),
                TASKS[task].name
            );
        }
    }

    /// No input plus a constant, and nothing read off y alone, is ever credited a task it
    /// does not compute: x+c earns ECHO, INC or DEC where it is one and nothing otherwise,
    /// and y and y±c earn nothing, over 10^5 drawn case sets. The zero-test scans earn what
    /// they compute on inputs that are never 0: `[<]>!` emits y, which is nothing, and
    /// `[<!]!` emits x first, which is ECHO.
    #[test]
    fn no_input_plus_a_constant_is_credited_a_task_it_is_not() {
        let plus = |reach: &[u8], step: u8, times: usize| {
            let mut tape = reach.to_vec();
            tape.extend(std::iter::repeat_n(step, times));
            tape.push(bff::EMIT);
            tape.push(b'>');
            tape
        };
        let mut tapes: Vec<(Vec<u8>, Credit)> = vec![
            (plus(b"<", b'+', 0), Credit(1)),
            (plus(b"<", b'+', 1), Credit(1 << 1)),
            (plus(b"<", b'-', 1), Credit(1 << 2)),
            (b"[<]>!".to_vec(), Credit::default()),
            (b"[<!]!".to_vec(), Credit(1)),
        ];
        for times in 2..=5 {
            tapes.push((plus(b"<", b'+', times), Credit::default()));
            tapes.push((plus(b"<", b'-', times), Credit::default()));
        }
        for times in 0..=5 {
            tapes.push((plus(b"<<", b'+', times), Credit::default()));
            tapes.push((plus(b"<<", b'-', times), Credit::default()));
        }
        let mut rng = rng::seeded(13, 0, 0);
        for _ in 0..100_000 {
            let cases = Cases::draw(&mut rng);
            for (tape, credit) in &tapes {
                assert_eq!(
                    assay(tape, &cases, OpSet::ALL),
                    *credit,
                    "{} on {cases:?}",
                    String::from_utf8_lossy(tape)
                );
            }
        }
    }

    #[test]
    fn the_draw_is_deterministic_and_moves_with_the_stream() {
        let draw = |epoch| Cases::draw(&mut rng::seeded(42, 7, epoch));
        assert_eq!(draw(8), draw(8));
        let distinct: std::collections::HashSet<_> = (0..64).map(draw).collect();
        assert!(distinct.len() > 60);
    }

    /// The tape's own instruction set binds inside the assay: without `+`, INC's program
    /// echoes x and earns ECHO, not INC.
    #[test]
    fn the_assay_runs_the_runs_own_instruction_set() {
        let no_inc = OpSet::parse("<>{}-.,[]").expect("a legal set");
        assert_eq!(
            assay(MINIMAL[1], &Cases::new(FALLBACK_CASES), no_inc),
            Credit(1)
        );
    }

    /// The run stops at the fourth emit, and the steal byte is a no-op that costs a step.
    #[test]
    fn a_case_stops_at_its_last_output_slot_and_never_steals() {
        let run = run_case(b"!!!!!!", 1, 2, OpSet::ALL);
        assert_eq!(run.outputs, vec![b'!'; TASK_MAX_OUTPUTS]);
        assert_eq!(run.steps, TASK_MAX_OUTPUTS as u32);

        let run = run_case(b"$<!", 9, 2, OpSet::ALL);
        assert_eq!(run.outputs, vec![9]);
        assert_eq!(
            run.steps, 6,
            "the steal byte cost its step and the run went on"
        );
    }

    /// The buffer is the tape and as many zeros, the inputs on its last two bytes: head0
    /// wraps left onto x and y, and the pointer runs to the end of the buffer.
    #[test]
    fn the_inputs_sit_at_the_end_of_a_buffer_twice_the_tape() {
        assert_eq!(run_case(b"<!", 4, 1, OpSet::ALL).outputs, vec![4]);
        assert_eq!(run_case(b"<<!", 4, 1, OpSet::ALL).outputs, vec![1]);
        assert_eq!(run_case(b"<<<!", 4, 1, OpSet::ALL).outputs, vec![0]);
        assert_eq!(run_case(b"ab", 1, 1, OpSet::ALL).steps, 4);
    }

    #[test]
    fn a_tape_without_the_emit_byte_is_never_run() {
        let cases = Cases::new(FALLBACK_CASES);
        assert_eq!(assay(b"<.>", &cases, OpSet::ALL), Credit::default());
        let mut memo = Memo::new(cases, OpSet::ALL);
        assert_eq!(memo.credit(b"<.>"), Credit::default());
        assert!(memo.seen.is_empty());
    }

    /// The rule that a paid emit is a carried one: this tape writes `!` into the zero
    /// half and points head0 at x, so its pointer emits x when it gets there, yet it
    /// holds no emit byte and is credited nothing.
    #[test]
    fn an_emit_the_tape_does_not_carry_earns_nothing() {
        let mut tape = b"<<<".to_vec();
        tape.extend([b'+'; bff::EMIT as usize]);
        tape.extend(b">>");
        assert!(!tape.contains(&bff::EMIT));
        for (x, y) in FALLBACK_CASES {
            assert_eq!(run_case(&tape, x, y, OpSet::ALL).outputs, vec![x]);
        }
        assert_eq!(credit_on(&tape, FALLBACK_CASES), Credit::default());
    }

    /// A tenth of 256 is 25.6, so 25 cells are not a capability and 26 are; the loop count
    /// reads only ADD onwards.
    #[test]
    fn a_capability_is_a_tenth_of_the_sampled_cells_counted_in_integers() {
        let mut tally = TaskTally::default();
        let echo_and_add = Credit(0b1001);
        for _ in 0..25 {
            tally.add(echo_and_add);
        }
        tally.add(Credit(0b1));
        assert_eq!((tally.credited(0), tally.credited(3)), (26, 25));
        assert_eq!(tally.share(0), 26.0 / 256.0);
        assert_eq!(tally.capability(), 1);
        assert_eq!(tally.capability_loop(), 0);

        tally.add(Credit(0b1000));
        assert_eq!(tally.capability(), 2);
        assert_eq!(tally.capability_loop(), 1);

        for _ in 0..26 {
            tally.add(Credit(0b1000_0110));
        }
        assert_eq!(tally.capability(), 5);
        assert_eq!(tally.capability_loop(), 2);
        assert_eq!(FIRST_LOOP_TASK, 3);
        assert_eq!(TASKS[FIRST_LOOP_TASK].name, "add");
    }

    #[test]
    fn the_memo_reads_what_the_assay_reads() {
        let cases = Cases::new(FALLBACK_CASES);
        let mut memo = Memo::new(cases, OpSet::ALL);
        for program in MINIMAL {
            assert_eq!(memo.credit(program), assay(program, &cases, OpSet::ALL));
            assert_eq!(memo.credit(program), assay(program, &cases, OpSet::ALL));
        }
        assert_eq!(memo.seen.len(), MINIMAL.len());
    }
}
