//! The logic assay (`docs/DESIGN.md` §1.1, "Tasks and the emit op"; the 2026-10-01
//! design-record entry on the logic assay): the task assay's buffer, emit, budget and cases,
//! with `bff::NAND` as an instruction beside the emit byte, and Avida's nine logic tasks
//! (Lenski et al. 2003) above an ECHO rung on whole-byte inputs. Every task is a composition
//! of NANDs, so a lower rung is a part of a higher one. The verdict is a pure function of
//! the tape, the cases, the run's instruction set and its `logic_nand`, as the arithmetic
//! assay's is of the first three.

use crate::bff::OpSet;
use crate::params::LogicNand;
use crate::rng::{self, Rng};
use crate::task::{self, TASK_CASES};
use std::collections::HashMap;

/// The most case draws one assay epoch makes before it falls back to `FALLBACK_CASES`.
/// About 27% of draws fail to separate, so the bound is never reached in practice; it is
/// there so the draw is total and deterministic.
pub const LOGIC_CASE_DRAWS: u32 = 1024;
/// The first entry of `LOGIC_TASKS` no measured evolved solver reaches within two
/// substitutions: XOR and EQU need a stored intermediate and four or five NANDs, where the
/// rungs below them are one or two substitutions from the rung beneath (the logic design
/// study, §5.1). The deep rungs are the ones rung 4 is read on.
pub const FIRST_DEEP_TASK: usize = 8;

/// One rung of the logic ladder: its name, the energy units it is worth per assay, and the
/// forms that credit it. A one-input or asymmetric task is credited for either operand
/// order: NOT of x or of y, ORN as x|!y or y|!x, ANDN as x&!y or y&!x, and ECHO as x or y.
#[derive(Debug, Clone, Copy)]
pub struct LogicTask {
    pub name: &'static str,
    pub units: u32,
    /// The fewest NANDs that compute the task; 0 for ECHO, which computes nothing.
    pub nands: u32,
    forms: &'static [fn(u8, u8) -> u8],
}

impl LogicTask {
    pub fn forms(&self) -> usize {
        self.forms.len()
    }

    /// The byte form `form` expects from inputs `x` and `y`.
    pub fn expected(&self, form: usize, x: u8, y: u8) -> u8 {
        (self.forms[form])(x, y)
    }
}

/// The logic ladder in ascending order of NANDs, units doubling with difficulty as Avida's
/// merits do, and an ECHO rung of one unit below it: the one-byte entry rung the arithmetic
/// ladder has, where NOT needs `~` and `!` placed together. The order is the bit order of a
/// `Credit`.
pub const LOGIC_TASKS: [LogicTask; 10] = [
    LogicTask {
        name: "echo",
        units: 1,
        nands: 0,
        forms: &[|x, _| x, |_, y| y],
    },
    LogicTask {
        name: "not",
        units: 1,
        nands: 1,
        forms: &[|x, _| !x, |_, y| !y],
    },
    LogicTask {
        name: "nand",
        units: 1,
        nands: 1,
        forms: &[|x, y| !(x & y)],
    },
    LogicTask {
        name: "and",
        units: 2,
        nands: 2,
        forms: &[|x, y| x & y],
    },
    LogicTask {
        name: "orn",
        units: 2,
        nands: 2,
        forms: &[|x, y| x | !y, |x, y| y | !x],
    },
    LogicTask {
        name: "or",
        units: 4,
        nands: 3,
        forms: &[|x, y| x | y],
    },
    LogicTask {
        name: "andn",
        units: 4,
        nands: 3,
        forms: &[|x, y| x & !y, |x, y| y & !x],
    },
    LogicTask {
        name: "nor",
        units: 8,
        nands: 4,
        forms: &[|x, y| !(x | y)],
    },
    LogicTask {
        name: "xor",
        units: 8,
        nands: 4,
        forms: &[|x, y| x ^ y],
    },
    LogicTask {
        name: "equ",
        units: 16,
        nands: 5,
        forms: &[|x, y| !(x ^ y)],
    },
];

/// ECHO's index on the ladder: its forms are x and y themselves, in that order.
const ECHO: usize = 0;

/// A set of cases that separates the ladder, used only if `LOGIC_CASE_DRAWS` draws in a row
/// all failed to.
const FALLBACK_CASES: [(u8, u8); TASK_CASES] = [(0x5a, 0x33), (0xc6, 0x9f), (0x21, 0xe8)];

/// The `(x, y)` inputs of one logic assay epoch, shared by every cell.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Cases([(u8, u8); TASK_CASES]);

impl Cases {
    /// Draws cases of whole random bytes, x then y for each case, until they separate the
    /// ladder (`separates`), from `rng` only.
    pub fn draw(rng: &mut Rng) -> Self {
        for _ in 0..LOGIC_CASE_DRAWS {
            let cases = Self(std::array::from_fn(|_| {
                let x = rng::byte(rng);
                let y = rng::byte(rng);
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

    /// Whether no constant, no wrong task and no cheap function of the inputs can pass, the
    /// logic design study's rule (§4.2) read with ECHO on the ladder:
    ///
    /// - the x values are pairwise distinct and so are the y values;
    /// - every form of every task expects pairwise distinct outputs, so no constant can;
    /// - no two forms of different tasks expect the same outputs, so one output slot
    ///   matches at most one task. ECHO's forms are the inputs, so this is also the
    ///   study's "no form and an input expect the same three";
    /// - no form's outputs sit a constant offset from x or from y, except ECHO's own form
    ///   of that input, so an input plus a constant, the cheapest thing a tape can emit,
    ///   earns nothing: not even ECHO, where x and y themselves sit a constant apart.
    pub fn separates(&self) -> bool {
        let xs = self.0.map(|(x, _)| x);
        let ys = self.0.map(|(_, y)| y);
        if !distinct(&xs) || !distinct(&ys) {
            return false;
        }
        let forms = self.forms();
        let distinct_within = forms.iter().all(|(_, _, outputs)| distinct(outputs));
        let distinct_across = forms.iter().enumerate().all(|(i, (task, _, outputs))| {
            forms[..i]
                .iter()
                .all(|(other, _, earlier)| other == task || earlier != outputs)
        });
        let no_offsets = forms.iter().all(|(task, form, outputs)| {
            [xs, ys].iter().enumerate().all(|(input, values)| {
                (*task == ECHO && *form == input) || !offset_of(outputs, values)
            })
        });
        distinct_within && distinct_across && no_offsets
    }

    /// Every form of every task: the index of its task, its own index among the task's
    /// forms, and the outputs it expects.
    fn forms(&self) -> Vec<(usize, usize, [u8; TASK_CASES])> {
        LOGIC_TASKS
            .iter()
            .enumerate()
            .flat_map(|(index, task)| {
                (0..task.forms()).map(move |form| (index, form, self.expected(task, form)))
            })
            .collect()
    }

    fn expected(&self, task: &LogicTask, form: usize) -> [u8; TASK_CASES] {
        self.0.map(|(x, y)| task.expected(form, x, y))
    }
}

fn distinct(values: &[u8; TASK_CASES]) -> bool {
    (1..TASK_CASES).all(|j| !values[..j].contains(&values[j]))
}

/// Whether `outputs` sit one constant offset, mod 256, from `input` in every case.
fn offset_of(outputs: &[u8; TASK_CASES], input: &[u8; TASK_CASES]) -> bool {
    let offsets: [u8; TASK_CASES] =
        std::array::from_fn(|case| outputs[case].wrapping_sub(input[case]));
    offsets.iter().all(|offset| *offset == offsets[0])
}

/// The logic tasks one tape was credited with, a bit per entry of `LOGIC_TASKS`.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub struct Credit(u16);

impl Credit {
    pub fn bits(self) -> u16 {
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
        LOGIC_TASKS
            .iter()
            .enumerate()
            .filter(|(index, _)| *index >= floor && self.has(*index))
            .map(|(_, task)| task.units)
            .sum()
    }
}

/// The logic tasks `tape` is credited with on `cases`: task t when some output slot holds
/// one of t's forms in every case. As in the arithmetic assay, a tape holding no emit byte
/// is credited nothing and never run. The NAND writes in place, as at `logic_nand`'s default.
pub fn assay(tape: &[u8], cases: &Cases, ops: OpSet) -> Credit {
    assay_on(tape, cases, ops, LogicNand::InPlace)
}

/// `assay` with the NAND `nand` names: in place, or onto the stack.
pub fn assay_on(tape: &[u8], cases: &Cases, ops: OpSet, nand: LogicNand) -> Credit {
    let Some(runs) = task::case_outputs(tape, cases.inputs(), ops, nand.assay_ops()) else {
        return Credit::default();
    };
    let mut bits = 0u16;
    for (index, task) in LOGIC_TASKS.iter().enumerate() {
        let held =
            (0..task.forms()).any(|form| task::slot_holds(&runs, cases.expected(task, form)));
        bits |= u16::from(held) << index;
    }
    Credit(bits)
}

/// The logic assay of many tapes on one epoch's cases, each distinct tape run once.
pub struct Memo<'a> {
    cases: Cases,
    ops: OpSet,
    nand: LogicNand,
    seen: HashMap<&'a [u8], Credit>,
}

impl<'a> Memo<'a> {
    pub fn new(cases: Cases, ops: OpSet, nand: LogicNand) -> Self {
        Self {
            cases,
            ops,
            nand,
            seen: HashMap::new(),
        }
    }

    pub fn credit(&mut self, tape: &'a [u8]) -> Credit {
        if !tape.contains(&crate::bff::EMIT) {
            return Credit::default();
        }
        let (cases, ops, nand) = (&self.cases, self.ops, self.nand);
        *self
            .seen
            .entry(tape)
            .or_insert_with(|| assay_on(tape, cases, ops, nand))
    }
}

/// How many of `task::TASK_SAMPLE_CELLS` sampled cells each logic rung was credited to: the
/// read-side tally of the logic observables (`docs/DESIGN.md` §1.2), the arithmetic
/// `task::TaskTally`'s counterpart on this ladder.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct LogicTally([u32; LOGIC_TASKS.len()]);

impl LogicTally {
    pub fn add(&mut self, credit: Credit) {
        for (task, credited) in self.0.iter_mut().enumerate() {
            *credited += u32::from(credit.has(task));
        }
    }

    pub fn credited(&self, task: usize) -> u32 {
        self.0[task]
    }

    pub fn share(&self, task: usize) -> f64 {
        f64::from(self.0[task]) / f64::from(task::TASK_SAMPLE_CELLS)
    }

    /// How many rungs at least a tenth of the sampled cells are credited with, by the
    /// arithmetic ladder's rule: 26 of 256, compared as integers.
    pub fn capability(&self) -> u32 {
        self.capable(0)
    }

    /// The same count over the deep rungs, XOR and EQU.
    pub fn capability_deep(&self) -> u32 {
        self.capable(FIRST_DEEP_TASK)
    }

    fn capable(&self, from: usize) -> u32 {
        self.0[from..]
            .iter()
            .filter(|credited| {
                **credited * task::TASK_CAPABILITY_DENOMINATOR >= task::TASK_SAMPLE_CELLS
            })
            .count() as u32
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bff::{self, AssayOps};

    /// A solver of each rung, head0 and head1 starting on byte 0 and wrapping left onto x
    /// and y: the design study's hand-written NOT, NAND, AND, OR, XOR and EQU (§4.2), and
    /// ECHO, ORN, ANDN and NOR written the same way.
    const SOLVERS: [&[u8]; 10] = [
        b"<!",
        b"<{~!",
        b"<<{~!",
        b"<<{~{~!",
        b"<{~<~!",
        b"<{~<{~}~!",
        b"<<{{~>~}~!",
        b"<{~<{~}~{~!",
        b"<<<{,{~>>{~<~}}~!",
        b"<<<{,{~>>{~<~}}~{~!",
    ];

    /// A solver of each rung under the stack NAND, where `~` writes left of head0 and head0
    /// follows: the design study's 13-byte XOR (§7.2) `<<{~~{{>>~{~!` and the same circuit
    /// with one more NAND for EQU, and the shortest program of each rung below them that an
    /// exhaustive search over `<>{},~!` finds.
    const STACK_SOLVERS: [&[u8]; 10] = [
        b"<!",
        b"<{~!",
        b"<<{~!",
        b"{{<~~!",
        b"<<{~~!",
        b"{,~<~~!",
        b"{,~{~~!",
        b"{,~{~>~~!",
        b"<<{~~{{>>~{~!",
        b"<<{~~{{>>~{~~!",
    ];

    /// Each solver computes a form of its own task on its first output slot over 4 096
    /// random byte inputs, through the assay's own buffer and interpreter, and on 10^5
    /// separating draws is credited with its own task and no other.
    #[test]
    fn each_solver_computes_its_task_and_is_credited_with_it_alone() {
        solvers_compute_their_tasks_alone(&SOLVERS, LogicNand::InPlace, 5);
    }

    /// The ladder re-proved under the stack NAND.
    #[test]
    fn each_stack_solver_computes_its_task_and_is_credited_with_it_alone() {
        solvers_compute_their_tasks_alone(&STACK_SOLVERS, LogicNand::Stack, 23);
    }

    fn solvers_compute_their_tasks_alone(solvers: &[&[u8]; 10], nand: LogicNand, seed: u64) {
        let mut rng = rng::seeded(seed, 0, 0);
        for (index, (solver, task)) in solvers.iter().zip(&LOGIC_TASKS).enumerate() {
            for _ in 0..4_096 {
                let (x, y) = (rng::byte(&mut rng), rng::byte(&mut rng));
                let first = task::run_case_on(solver, x, y, OpSet::ALL, nand.assay_ops())
                    .outputs
                    .first()
                    .copied();
                assert!(
                    (0..task.forms()).any(|form| first == Some(task.expected(form, x, y))),
                    "{} on ({x}, {y}): {first:?}",
                    task.name
                );
            }
            let mut rng = rng::seeded(seed + 2, 0, index as u64);
            for _ in 0..100_000 {
                let cases = Cases::draw(&mut rng);
                let credit = assay_on(solver, &cases, OpSet::ALL, nand);
                assert_eq!(credit, Credit(1 << index), "{} on {cases:?}", task.name);
            }
        }
    }

    /// The pilot's evolved deep solver under the stack NAND (the design study, §7.4),
    /// `<<[~><~{~{!]` behind the `{` its tape carried: each lap stacks three NANDs leftward and
    /// head1 trails onto what earlier laps wrote, so the laps emit ¬y, XOR, ¬y and EQU. It
    /// computes three rungs and is credited with those and no other. A lap that leaves a zero
    /// under head0 ends the loop early, so it is credited all three on most draws, not all.
    #[test]
    fn the_evolved_stack_loop_computes_not_xor_and_equ() {
        let tape = b"{<<[~><~{~{!]";
        let mut rng = rng::seeded(29, 0, 0);
        let mut whole = 0;
        for _ in 0..4_096 {
            let (x, y) = (rng::byte(&mut rng), rng::byte(&mut rng));
            let outputs =
                task::run_case_on(tape, x, y, OpSet::ALL, AssayOps::EmitStackNand).outputs;
            let laps = [!y, x ^ y, !y, !(x ^ y)];
            assert_eq!(outputs[..], laps[..outputs.len()], "({x}, {y})");
            whole += usize::from(outputs.len() == laps.len());
        }
        assert!(whole > 4_000, "only {whole} runs went four laps");
        let (not, xor, equ) = (Credit(1 << 1), Credit(1 << 8), Credit(1 << 9));
        let three = Credit(not.bits() | xor.bits() | equ.bits());
        let mut credited = 0;
        for _ in 0..100_000 {
            let cases = Cases::draw(&mut rng);
            let credit = assay_on(tape, &cases, OpSet::ALL, LogicNand::Stack);
            assert_eq!(credit.bits() & !three.bits(), 0, "{cases:?}: {credit:?}");
            credited += usize::from(credit == three);
        }
        assert!(
            credited > 95_000,
            "credited all three on only {credited} draws"
        );
    }

    #[test]
    fn the_ladder_is_worth_what_the_design_says() {
        let names: Vec<&str> = LOGIC_TASKS.iter().map(|task| task.name).collect();
        assert_eq!(
            names,
            ["echo", "not", "nand", "and", "orn", "or", "andn", "nor", "xor", "equ"]
        );
        let units: Vec<u32> = LOGIC_TASKS.iter().map(|task| task.units).collect();
        assert_eq!(units, [1, 1, 1, 2, 2, 4, 4, 8, 8, 16]);
        let nands: Vec<u32> = LOGIC_TASKS.iter().map(|task| task.nands).collect();
        assert_eq!(nands, [0, 1, 1, 2, 2, 3, 3, 4, 4, 5]);
        let forms: Vec<usize> = LOGIC_TASKS.iter().map(LogicTask::forms).collect();
        assert_eq!(forms, [2, 2, 1, 1, 2, 1, 2, 1, 1, 1]);
        assert_eq!(Credit(0x3ff).units(), 47);
        assert_eq!(Credit(0b11).units(), 2);
        assert_eq!(LOGIC_TASKS[FIRST_DEEP_TASK].name, "xor");
        assert_eq!(LOGIC_TASKS.len() - FIRST_DEEP_TASK, 2);
    }

    /// The floor drops the rungs below it from the pay and keeps the rest: XOR's floor pays
    /// XOR and EQU only.
    #[test]
    fn the_units_from_a_floor_count_only_the_rungs_at_or_above_it() {
        let everything = Credit(0x3ff);
        assert_eq!(everything.units_from(0), 47);
        assert_eq!(everything.units_from(FIRST_DEEP_TASK), 24);
        assert_eq!(everything.units_from(LOGIC_TASKS.len()), 0);
        let low_and_xor = Credit(0b01_0000_0111);
        assert_eq!(low_and_xor.units_from(0), 11);
        assert_eq!(low_and_xor.units_from(1), 10);
        assert_eq!(low_and_xor.units_from(3), 8);
        assert_eq!(low_and_xor.units_from(9), 0);
    }

    /// No copying can fake a credit, and no constant: a pure copier emits nothing, a copier
    /// with a junk emit emits a byte of itself whatever the inputs, a sprayer emits a
    /// constant in each slot, and a tape of `~` and `!` with no head move NANDs and emits
    /// bytes of itself. A tape that echoes an input is credited ECHO and nothing else, and
    /// an input plus a constant earns nothing at all.
    #[test]
    fn copiers_constants_and_sprayers_are_credited_nothing_but_echo() {
        let mut copier = b"{[.<>>{]".to_vec();
        copier.resize(64, b'a');
        let mut junk_emit = b"{[.<!>>{]".to_vec();
        junk_emit.resize(64, b'a');
        let mut forward = b"}}}}[,>}!]".to_vec();
        forward.resize(64, 1);
        let mut echoing_copier = b"<!>{[.<>>{]".to_vec();
        echoing_copier.resize(64, b'a');
        let echo = Credit(1);
        let tapes: [(&[u8], Credit); 16] = [
            (&copier, Credit::default()),
            (&junk_emit, Credit::default()),
            (&forward, Credit::default()),
            (b"[!+]", Credit::default()),
            (b"+[!+]", Credit::default()),
            (b"!!!!", Credit::default()),
            (b"~!~!~!", Credit::default()),
            (b"+!+!+!+!", Credit::default()),
            (b">!", Credit::default()),
            (b"<+!", Credit::default()),
            (b"<<---!", Credit::default()),
            (&echoing_copier, echo),
            (b"<!", echo),
            (b"<<!", echo),
            (b"<!+!-!", echo),
            (b"<{.!", echo),
        ];
        let mut rng = rng::seeded(3, 0, 0);
        for _ in 0..100_000 {
            let cases = Cases::draw(&mut rng);
            for (tape, credit) in tapes {
                assert_eq!(
                    assay(tape, &cases, OpSet::ALL),
                    credit,
                    "{:?} on {cases:?}",
                    String::from_utf8_lossy(tape)
                );
            }
        }
    }

    /// The separating rule, over 10^5 draws, read off the inputs and the ladder directly:
    /// no draw is returned that fails it, and the fallback passes it too.
    #[test]
    fn every_drawn_set_of_cases_separates_the_ladder() {
        let distinct = |values: [u8; TASK_CASES]| {
            values[0] != values[1] && values[1] != values[2] && values[0] != values[2]
        };
        let offset = |outputs: [u8; TASK_CASES], input: [u8; TASK_CASES]| {
            let first = outputs[0].wrapping_sub(input[0]);
            (1..TASK_CASES).all(|case| outputs[case].wrapping_sub(input[case]) == first)
        };
        let holds = |cases: &Cases| {
            let inputs = *cases.inputs();
            let (xs, ys) = (inputs.map(|(x, _)| x), inputs.map(|(_, y)| y));
            assert!(distinct(xs) && distinct(ys), "{cases:?}");
            for (t, task) in LOGIC_TASKS.iter().enumerate() {
                for form in 0..task.forms() {
                    let outputs = inputs.map(|(x, y)| task.expected(form, x, y));
                    assert!(distinct(outputs), "{} on {cases:?}", task.name);
                    for (u, other) in LOGIC_TASKS.iter().enumerate().filter(|(u, _)| *u != t) {
                        for theirs in 0..other.forms() {
                            let expected = inputs.map(|(x, y)| other.expected(theirs, x, y));
                            assert_ne!(
                                expected, outputs,
                                "{} and {} on {cases:?}",
                                task.name, LOGIC_TASKS[u].name
                            );
                        }
                    }
                    for (which, input) in [xs, ys].into_iter().enumerate() {
                        let own = t == 0 && form == which;
                        assert!(own || !offset(outputs, input), "{} on {cases:?}", task.name);
                    }
                }
            }
        };
        let mut rng = rng::seeded(11, 0, 0);
        for _ in 0..100_000 {
            let cases = Cases::draw(&mut rng);
            assert!(cases.separates(), "{cases:?}");
            holds(&cases);
        }
        let fallback = Cases::new(FALLBACK_CASES);
        assert!(fallback.separates());
        holds(&fallback);
    }

    /// The traps the rule closes, each on cases it refuses and where a tape would be
    /// credited a task it does not compute: where y is x plus 1 in every case, `<<-!` emits
    /// y−1 and passes for ECHO; where x's bits all lie in y's, `<!` echoes x and passes for
    /// AND.
    #[test]
    fn the_separating_rule_closes_each_trap_a_cheap_tape_springs() {
        let traps = [
            (&b"<<-!"[..], [(0x5a, 0x5b), (0xc6, 0xc7), (0x21, 0x22)], 0),
            (b"<!", [(0x01, 0x03), (0x04, 0x0c), (0x10, 0x30)], 3),
        ];
        for (tape, inputs, task) in traps {
            let cases = Cases::new(inputs);
            assert!(!cases.separates(), "{inputs:?}");
            let credit = assay(tape, &cases, OpSet::ALL);
            assert!(
                credit.has(task),
                "{} would earn {} on {inputs:?}: {credit:?}",
                String::from_utf8_lossy(tape),
                LOGIC_TASKS[task].name
            );
        }
    }

    #[test]
    fn the_draw_is_deterministic_and_moves_with_the_stream() {
        let draw = |epoch| Cases::draw(&mut rng::seeded(42, 7, epoch));
        assert_eq!(draw(8), draw(8));
        let distinct: std::collections::HashSet<_> = (0..64).map(draw).collect();
        assert_eq!(distinct.len(), 64);
    }

    /// `~` is the logic assay's alone: the arithmetic assay runs the NOT solver with `~` a
    /// no-op, so it emits x and earns ECHO there.
    #[test]
    fn the_arithmetic_assay_reads_the_nand_byte_as_a_no_op() {
        let mut rng = rng::seeded(13, 0, 0);
        for _ in 0..1_000 {
            let cases = task::Cases::draw(&mut rng);
            assert_eq!(task::assay(SOLVERS[1], &cases, OpSet::ALL).bits(), 1);
        }
    }

    #[test]
    fn a_tape_without_the_emit_byte_is_never_run() {
        let cases = Cases::new(FALLBACK_CASES);
        assert_eq!(assay(b"<{~", &cases, OpSet::ALL), Credit::default());
        let mut memo = Memo::new(cases, OpSet::ALL, LogicNand::InPlace);
        assert_eq!(memo.credit(b"<{~"), Credit::default());
        assert!(memo.seen.is_empty());
        assert!(!b"<{~".contains(&bff::EMIT));
    }

    #[test]
    fn the_memo_reads_what_the_assay_reads() {
        let cases = Cases::draw(&mut rng::seeded(17, 0, 0));
        let mut memo = Memo::new(cases, OpSet::ALL, LogicNand::InPlace);
        for solver in SOLVERS {
            assert_eq!(memo.credit(solver), assay(solver, &cases, OpSet::ALL));
            assert_eq!(memo.credit(solver), assay(solver, &cases, OpSet::ALL));
        }
        assert_eq!(memo.seen.len(), SOLVERS.len());
    }

    /// A tenth of 256 is 25.6, so 25 cells are not a capability and 26 are; the deep count
    /// reads only XOR and EQU, not NOR just below them.
    #[test]
    fn a_logic_capability_is_a_tenth_of_the_sampled_cells_counted_in_integers() {
        let mut tally = LogicTally::default();
        let not_and_xor = Credit(0b01_0000_0010);
        for _ in 0..25 {
            tally.add(not_and_xor);
        }
        tally.add(Credit(0b10));
        assert_eq!((tally.credited(1), tally.credited(8)), (26, 25));
        assert_eq!(tally.share(1), 26.0 / 256.0);
        assert_eq!(tally.capability(), 1);
        assert_eq!(tally.capability_deep(), 0);

        for _ in 0..26 {
            tally.add(Credit(1 << (FIRST_DEEP_TASK - 1)));
        }
        assert_eq!(tally.capability(), 2);
        assert_eq!(tally.capability_deep(), 0);

        tally.add(Credit(1 << 8));
        assert_eq!(tally.capability(), 3);
        assert_eq!(tally.capability_deep(), 1);

        for _ in 0..26 {
            tally.add(Credit(0b10_0010_0001));
        }
        assert_eq!(tally.capability(), 6);
        assert_eq!(tally.capability_deep(), 2);
    }
}
