//! Reading (d): whether a solver reads an input twice, by a traced stepper.
//!
//! The stepper runs the logic assay's machine by the book — the buffer, heads, budget and
//! emit limit of `task::run_case`, the run's instruction set and its NAND — and gives every
//! byte it writes a provenance: an input, a constant of the buffer, a NAND of two values, or
//! an increment of one. A copy (`.` or `,`) moves a value without making a new one, so a
//! stored copy of x is still x.
//!
//! An emitted byte is the root of a circuit. A value **is read twice** when two different
//! NANDs of that circuit take it as an operand: an input or an intermediate fanned out. A
//! NAND whose two operands are one value (NOT as NAND(x, x)) reads it once, as the study's
//! read-once table counts it. The rule names the circuit, not its depth: a read-once rung
//! can be built by a circuit that reads an input twice.

use crate::score::Scorer;
use life_engine::bff::{self, AssayOps};
use life_engine::logic::LOGIC_TASKS;
use life_engine::params::LogicNand;
use life_engine::task::{TASK_MAX_OUTPUTS, TASK_STEPS};
use life_engine::OpSet;
use std::collections::HashMap;
use std::fmt::Write;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Value {
    X,
    Y,
    /// The byte a buffer position held at the start.
    Constant(usize),
    Nand(usize, usize),
    /// An increment or decrement of a value.
    Shifted(usize),
}

pub struct Trace {
    pub outputs: Vec<u8>,
    /// The value each output byte is.
    pub emitted: Vec<usize>,
    pub steps: u32,
    pub values: Vec<Value>,
    /// One line per acting step, as the study's `explain` printed them.
    pub lines: Vec<String>,
    /// The id of the first value the run made, past the buffer's bytes and the inputs.
    made_from: usize,
}

/// Runs `tape` on one case as the logic assay does.
pub fn run(tape: &[u8], x: u8, y: u8, ops: OpSet, nand: LogicNand) -> Trace {
    let len = 2 * tape.len();
    let mut buffer = tape.to_vec();
    buffer.resize(len, 0);
    let mut values: Vec<Value> = (0..len).map(Value::Constant).collect();
    let mut at: Vec<usize> = (0..len).collect();
    if len >= 2 {
        buffer[len - 1] = x;
        buffer[len - 2] = y;
        values.push(Value::X);
        values.push(Value::Y);
        at[len - 1] = len;
        at[len - 2] = len + 1;
    }
    let mut trace = Trace {
        outputs: Vec::new(),
        emitted: Vec::new(),
        steps: 0,
        values,
        lines: Vec::new(),
        made_from: len + 2,
    };
    if len == 0 {
        return trace;
    }
    let place = |head: usize| -> String {
        if head >= tape.len() {
            format!("E{}", head as i64 - len as i64)
        } else {
            head.to_string()
        }
    };
    let (mut ip, mut h0, mut h1) = (0usize, 0usize, 0usize);
    while ip < len {
        if trace.steps == TASK_STEPS {
            break;
        }
        trace.steps += 1;
        let op = buffer[ip];
        let enabled = op == bff::EMIT || op == bff::NAND || ops.enables(op);
        let mut line = None;
        if enabled {
            match op {
                b'<' => h0 = (h0 + len - 1) % len,
                b'>' => h0 = (h0 + 1) % len,
                b'{' => h1 = (h1 + len - 1) % len,
                b'}' => h1 = (h1 + 1) % len,
                b'+' | b'-' => {
                    let before = buffer[h0];
                    buffer[h0] = if op == b'+' {
                        before.wrapping_add(1)
                    } else {
                        before.wrapping_sub(1)
                    };
                    trace.values.push(Value::Shifted(at[h0]));
                    at[h0] = trace.values.len() - 1;
                    line = Some(format!(
                        "{} h0={} {before:#04x}->{:#04x}",
                        op as char,
                        place(h0),
                        buffer[h0]
                    ));
                }
                b'.' => {
                    buffer[h1] = buffer[h0];
                    at[h1] = at[h0];
                    line = Some(format!(
                        ". h0={} {:#04x} -> h1={}",
                        place(h0),
                        buffer[h0],
                        place(h1)
                    ));
                }
                b',' => {
                    buffer[h0] = buffer[h1];
                    at[h0] = at[h1];
                    line = Some(format!(
                        ", h1={} {:#04x} -> h0={}",
                        place(h1),
                        buffer[h1],
                        place(h0)
                    ));
                }
                bff::NAND => {
                    let (a, b) = (buffer[h0], buffer[h1]);
                    trace.values.push(Value::Nand(at[h0], at[h1]));
                    let (from0, from1) = (h0, h1);
                    if nand == LogicNand::Stack {
                        h0 = (h0 + len - 1) % len;
                    }
                    buffer[h0] = !(a & b);
                    at[h0] = trace.values.len() - 1;
                    line = Some(format!(
                        "~ h0={}({a:#04x}) h1={}({b:#04x}) -> {:#04x} into {}",
                        place(from0),
                        place(from1),
                        buffer[h0],
                        place(h0)
                    ));
                }
                bff::EMIT => {
                    trace.outputs.push(buffer[h0]);
                    trace.emitted.push(at[h0]);
                    trace.lines.push(format!(
                        "step {:5} ip {ip:3}: ! emit h0={} {:#04x} [output {}]",
                        trace.steps,
                        place(h0),
                        buffer[h0],
                        trace.outputs.len()
                    ));
                    if trace.outputs.len() >= TASK_MAX_OUTPUTS {
                        break;
                    }
                }
                b'[' if buffer[h0] == 0 => match matching(&buffer, ip, true) {
                    Some(target) => ip = target,
                    None => break,
                },
                b']' if buffer[h0] != 0 => match matching(&buffer, ip, false) {
                    Some(target) => ip = target,
                    None => break,
                },
                _ => {}
            }
        }
        if let Some(line) = line {
            trace
                .lines
                .push(format!("step {:5} ip {ip:3}: {line}", trace.steps));
        }
        ip += 1;
    }
    trace
}

fn matching(buffer: &[u8], ip: usize, forward: bool) -> Option<usize> {
    let (open, close) = if forward { (b'[', b']') } else { (b']', b'[') };
    let mut depth = 1usize;
    let mut scan: Box<dyn Iterator<Item = usize>> = if forward {
        Box::new(ip + 1..buffer.len())
    } else {
        Box::new((0..ip).rev())
    };
    scan.find(|at| {
        if buffer[*at] == open {
            depth += 1;
        } else if buffer[*at] == close {
            depth -= 1;
        }
        depth == 0
    })
}

impl Trace {
    /// The values of the circuit behind output `slot` that two different NANDs of it take
    /// as an operand, each with how many do.
    pub fn read_twice(&self, slot: usize) -> Vec<(usize, usize)> {
        let mut readers: HashMap<usize, usize> = HashMap::new();
        let mut seen = vec![false; self.values.len()];
        let mut stack = vec![self.emitted[slot]];
        while let Some(value) = stack.pop() {
            if std::mem::replace(&mut seen[value], true) {
                continue;
            }
            match self.values[value] {
                Value::Nand(a, b) => {
                    *readers.entry(a).or_default() += 1;
                    if b != a {
                        *readers.entry(b).or_default() += 1;
                    }
                    stack.extend([a, b]);
                }
                Value::Shifted(a) => stack.push(a),
                _ => {}
            }
        }
        let mut twice: Vec<(usize, usize)> = readers
            .into_iter()
            .filter(|(value, readers)| {
                *readers >= 2 && !matches!(self.values[*value], Value::Constant(_))
            })
            .collect();
        twice.sort_unstable();
        twice
    }

    /// A value's short name: `x`, `y`, `c<position>` for a byte the buffer started with,
    /// `t<id>` for a NAND and `s<id>` for a shift.
    pub fn name(&self, value: usize) -> String {
        match self.values[value] {
            Value::X => "x".into(),
            Value::Y => "y".into(),
            Value::Constant(at) => format!("c{at}"),
            Value::Nand(..) => format!("t{}", value + 1 - self.made_from),
            Value::Shifted(_) => format!("s{}", value + 1 - self.made_from),
        }
    }

    /// Whether x or y itself is an operand of two different NANDs behind output `slot`.
    pub fn input_read_twice(&self, slot: usize) -> bool {
        self.read_twice(slot)
            .iter()
            .any(|(value, _)| matches!(self.values[*value], Value::X | Value::Y))
    }

    /// One level of a value: `NAND(t3, x)` for a NAND, its name otherwise.
    pub fn define(&self, value: usize) -> String {
        match self.values[value] {
            Value::Nand(a, b) => format!("NAND({}, {})", self.name(a), self.name(b)),
            Value::Shifted(a) => format!("shift({})", self.name(a)),
            _ => self.name(value),
        }
    }

    /// The NANDs and shifts behind output `slot`, in the order they were made.
    pub fn circuit(&self, slot: usize) -> Vec<usize> {
        let mut seen = vec![false; self.values.len()];
        let mut stack = vec![self.emitted[slot]];
        while let Some(value) = stack.pop() {
            if std::mem::replace(&mut seen[value], true) {
                continue;
            }
            match self.values[value] {
                Value::Nand(a, b) => stack.extend([a, b]),
                Value::Shifted(a) => stack.push(a),
                _ => {}
            }
        }
        (0..self.values.len())
            .filter(|value| {
                seen[*value] && matches!(self.values[*value], Value::Nand(..) | Value::Shifted(_))
            })
            .collect()
    }
}

/// The output slot of each case set that holds a form of `rung` on every case, if any.
fn credited_slot(outputs: &[Vec<u8>], cases: &[(u8, u8)], rung: usize) -> Option<usize> {
    let task = &LOGIC_TASKS[rung];
    (0..TASK_MAX_OUTPUTS).find(|slot| {
        (0..task.forms()).any(|form| {
            outputs
                .iter()
                .zip(cases)
                .all(|(out, (x, y))| out.get(*slot) == Some(&task.expected(form, *x, *y)))
        })
    })
}

pub struct Reading {
    pub rung: usize,
    /// Over the six sets' cases where the rung is credited: how many there are, and in how
    /// many its circuit reads a value twice.
    pub cases: usize,
    pub read_twice: usize,
    /// Of those, the cases where x or y itself is an operand of two different NANDs.
    pub input_twice: usize,
    /// The traced case, its slot computing the rung if one does, and what that circuit
    /// reads twice.
    pub traced: Trace,
    pub traced_slot: Option<usize>,
}

/// The reading on `tape` for `rung`: the six fixed sets and the traced case.
pub fn reading(tape: &[u8], scorer: &Scorer, rung: usize) -> Reading {
    let (mut cases, mut read_twice, mut input_twice) = (0, 0, 0);
    for set in scorer.sets() {
        let inputs = set.inputs();
        let traces: Vec<Trace> = inputs
            .iter()
            .map(|(x, y)| run(tape, *x, *y, scorer.ops(), scorer.nand()))
            .collect();
        let outputs: Vec<Vec<u8>> = traces.iter().map(|t| t.outputs.clone()).collect();
        if let Some(slot) = credited_slot(&outputs, inputs, rung) {
            cases += traces.len();
            read_twice += traces
                .iter()
                .filter(|t| !t.read_twice(slot).is_empty())
                .count();
            input_twice += traces.iter().filter(|t| t.input_read_twice(slot)).count();
        }
    }
    let (x, y) = crate::score::TRACE_CASE;
    let traced = run(tape, x, y, scorer.ops(), scorer.nand());
    let traced_slot = credited_slot(std::slice::from_ref(&traced.outputs), &[(x, y)], rung);
    Reading {
        rung,
        cases,
        read_twice,
        input_twice,
        traced,
        traced_slot,
    }
}

impl Reading {
    /// Whether the rung's circuit reads a value twice in every case it is credited on.
    pub fn reads_twice(&self) -> bool {
        self.cases > 0 && self.read_twice == self.cases
    }

    /// Whether it reads x or y itself twice in every case it is credited on.
    pub fn reads_an_input_twice(&self) -> bool {
        self.cases > 0 && self.input_twice == self.cases
    }

    pub fn render(&self, lines: usize) -> String {
        let mut out = String::new();
        let (x, y) = crate::score::TRACE_CASE;
        let _ = writeln!(out, "traced on x={x:#04x} y={y:#04x}:");
        for line in self.traced.lines.iter().take(lines) {
            let _ = writeln!(out, "  {line}");
        }
        if self.traced.lines.len() > lines {
            let _ = writeln!(
                out,
                "  … {} more acting steps",
                self.traced.lines.len() - lines
            );
        }
        let _ = writeln!(
            out,
            "outputs {:02x?} in {} steps",
            self.traced.outputs, self.traced.steps
        );
        for slot in 0..self.traced.outputs.len() {
            let twice: Vec<String> = self
                .traced
                .read_twice(slot)
                .iter()
                .map(|(value, readers)| format!("{} by {readers} NANDs", self.traced.name(*value)))
                .collect();
            let mark = if self.traced_slot == Some(slot) {
                format!(" (computes {})", LOGIC_TASKS[self.rung].name)
            } else {
                String::new()
            };
            let _ = writeln!(
                out,
                "  slot {slot}{mark} = {}: {}",
                self.traced.name(self.traced.emitted[slot]),
                if twice.is_empty() {
                    "reads every value once".to_string()
                } else {
                    format!("reads twice: {}", twice.join("; "))
                }
            );
            if self.traced_slot == Some(slot) {
                for value in self.traced.circuit(slot) {
                    let _ = writeln!(
                        out,
                        "      {} = {}",
                        self.traced.name(value),
                        self.traced.define(value)
                    );
                }
            }
        }
        let _ = writeln!(
            out,
            "{}: credited in {} of 18 cases on the 6 fixed sets; its circuit reads an input or an \
             intermediate twice in {} ({}), an input itself twice in {} ({})",
            LOGIC_TASKS[self.rung].name,
            self.cases,
            self.read_twice,
            verdict(self.cases, self.reads_twice()),
            self.input_twice,
            verdict(self.cases, self.reads_an_input_twice()),
        );
        out
    }
}

fn verdict(cases: usize, every: bool) -> &'static str {
    match (cases, every) {
        (0, _) => "not credited",
        (_, true) => "every case",
        _ => "not every case",
    }
}

/// The engine's own run of one case, the reference the stepper is held to.
pub fn engine_case(tape: &[u8], x: u8, y: u8, ops: OpSet, nand: LogicNand) -> (Vec<u8>, u32) {
    let len = 2 * tape.len();
    let mut buffer = tape.to_vec();
    buffer.resize(len, 0);
    if len >= 2 {
        buffer[len - 1] = x;
        buffer[len - 2] = y;
    }
    let mut emitted = bff::Emitted {
        bytes: Vec::new(),
        most: TASK_MAX_OUTPUTS,
    };
    let bounds = bff::Bounds {
        max_steps: TASK_STEPS,
        enabled: ops,
        cap: len,
        code_len: len,
    };
    let assay_ops: AssayOps = nand.assay_ops();
    let outcome = bff::run_emitting(&mut buffer, bounds, &mut emitted, assay_ops);
    (emitted.bytes, outcome.steps)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::score::tests::{meta_stack_params, stack_solver, IN_PLACE_EQU, IN_PLACE_XOR};
    use crate::tape::{parse, ALPHABET};
    use life_engine::rng;

    /// The stepper emits what the engine's assay emits, in as many steps, on random tapes
    /// of the alphabet and of whole bytes, under both NANDs and a reduced instruction set.
    #[test]
    fn the_stepper_agrees_with_the_engine() {
        let mut noise = rng::seeded(41, 0, 0);
        let reduced = OpSet::parse("<>{},.[]").unwrap();
        for trial in 0..20_000 {
            let len = 4 + rng::below(&mut noise, 29) as usize;
            let tape: Vec<u8> = (0..len)
                .map(|_| match trial % 2 {
                    0 => ALPHABET[rng::below(&mut noise, 14) as usize],
                    _ => rng::byte(&mut noise),
                })
                .collect();
            let (x, y) = (rng::byte(&mut noise), rng::byte(&mut noise));
            for nand in [LogicNand::InPlace, LogicNand::Stack] {
                for ops in [OpSet::ALL, reduced] {
                    let traced = run(&tape, x, y, ops, nand);
                    assert_eq!(
                        (traced.outputs, traced.steps),
                        engine_case(&tape, x, y, ops, nand),
                        "{tape:?} on ({x}, {y}) under {nand:?}"
                    );
                }
            }
        }
    }

    fn scorer(nand: LogicNand) -> Scorer {
        Scorer::for_params(&life_engine::Params {
            logic_nand: nand,
            ..meta_stack_params()
        })
    }

    #[test]
    fn the_deep_solvers_read_a_value_twice() {
        let stack = scorer(LogicNand::Stack);
        for rung in [8, 9] {
            let reading = reading(&stack_solver(rung), &stack, rung);
            assert_eq!(reading.cases, 18);
            assert!(reading.reads_twice(), "{}", reading.render(0));
            assert!(reading.reads_an_input_twice());
            assert_eq!(reading.traced_slot, Some(0));
        }
        let in_place = scorer(LogicNand::InPlace);
        for (solver, rung) in [(IN_PLACE_XOR, 8), (IN_PLACE_EQU, 9)] {
            let reading = reading(&parse(solver, 32).unwrap(), &in_place, rung);
            assert!(reading.reads_twice(), "{}", reading.render(0));
        }
    }

    /// NOT as NAND(x, x) reads x once; NAND reads each input once; ECHO computes nothing.
    #[test]
    fn the_one_nand_rungs_read_every_value_once() {
        let stack = scorer(LogicNand::Stack);
        for rung in [0, 1, 2] {
            let reading = reading(&stack_solver(rung), &stack, rung);
            assert_eq!(reading.cases, 18);
            assert_eq!(reading.read_twice, 0, "{}", reading.render(0));
        }
    }

    /// The stack ORN `<<{~~!` is NAND(NAND(y, x), x): a read-once rung whose circuit reads
    /// x twice. The reading describes the circuit, not the rung.
    #[test]
    fn a_read_once_rung_can_be_built_reading_an_input_twice() {
        let trace = run(&stack_solver(4), 0x5a, 0x33, OpSet::ALL, LogicNand::Stack);
        let twice = trace.read_twice(0);
        assert_eq!(twice.len(), 1);
        assert_eq!(trace.name(twice[0].0), "x");
        assert_eq!(twice[0].1, 2);
        assert!(trace.input_read_twice(0));
    }

    /// A stored copy of an input is still that input.
    #[test]
    fn a_copy_moves_a_value_without_making_a_new_one() {
        let trace = run(b"<<{,~!", 0x5a, 0x33, OpSet::ALL, LogicNand::InPlace);
        assert_eq!(trace.outputs, vec![!0x5a]);
        assert_eq!(trace.define(trace.emitted[0]), "NAND(x, x)");
        assert!(trace.read_twice(0).is_empty());
    }
}
