//! Exact synthesis by SAT: is there a circuit of exactly `k` gates computing f? Each gate picks
//! one operand pair among the earlier nodes, and its value on every row is the NAND of the
//! pair's. The circuit is held to the canonical form of [`crate::enumerate`] — operand pairs
//! strictly increasing, every gate a function present nowhere else (not an input, not another
//! gate, not a constant when f is not one) and every gate but the output read by a later one —
//! which every minimal circuit takes after reordering. So UNSAT at every size below k proves f
//! needs k, and a SAT model is a witness.

use crate::circuit::Circuit;
use crate::tt::{self, Tt};

/// A DIMACS literal: variable v ≥ 1 positive, −v its negation.
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
struct Lit(i32);

impl std::ops::Not for Lit {
    type Output = Lit;

    fn not(self) -> Lit {
        Lit(-self.0)
    }
}

#[derive(Clone, Copy)]
enum Val {
    Const(bool),
    Var(Lit),
}

impl std::ops::Not for Val {
    type Output = Val;

    fn not(self) -> Val {
        match self {
            Val::Const(b) => Val::Const(!b),
            Val::Var(l) => Val::Var(!l),
        }
    }
}

#[derive(Default)]
struct Cnf {
    vars: i32,
    clauses: Vec<Vec<i32>>,
}

impl Cnf {
    fn var(&mut self) -> Lit {
        self.vars += 1;
        Lit(self.vars)
    }

    /// Adds the clause, dropping false constants; a true constant satisfies it outright.
    fn clause(&mut self, vals: &[Val]) {
        let mut lits = Vec::with_capacity(vals.len());
        for &v in vals {
            match v {
                Val::Const(true) => return,
                Val::Const(false) => {}
                Val::Var(l) => lits.push(l.0),
            }
        }
        self.clauses.push(lits);
    }

    /// The model, indexed by variable (index 0 unused), or `None` when UNSAT.
    fn solve(&self) -> Option<Vec<bool>> {
        use varisat::ExtendFormula;
        let mut solver = varisat::Solver::new();
        let lits: Vec<varisat::Lit> = (0..self.vars).map(|_| solver.new_lit()).collect();
        let lit = |l: i32| {
            if l > 0 {
                lits[l as usize - 1]
            } else {
                !lits[(-l) as usize - 1]
            }
        };
        for c in &self.clauses {
            solver.add_clause(&c.iter().map(|&l| lit(l)).collect::<Vec<_>>());
        }
        if !solver.solve().expect("the solver runs") {
            return None;
        }
        let model: std::collections::HashSet<varisat::Lit> = solver.model()?.into_iter().collect();
        Some(
            (0..=self.vars)
                .map(|v| v > 0 && model.contains(&lit(v)))
                .collect(),
        )
    }
}

/// The operand pairs open to gate `g` (node `inputs + g`), in canonical order: by max, then min.
fn pairs(inputs: usize, g: usize) -> Vec<(usize, usize)> {
    let n = inputs + g;
    (0..n).flat_map(|b| (0..=b).map(move |a| (a, b))).collect()
}

/// The clauses every canonical circuit of exactly `gates` gates satisfies: each gate's pair
/// and values, pairs strictly increasing, and every gate's function new. `output` fixes the
/// last gate's values; `constants` lets non-output gates be constant.
struct Encoding {
    cnf: Cnf,
    inputs: usize,
    gates: usize,
    value: Vec<Vec<Val>>,
    select: Vec<Vec<Lit>>,
}

impl Encoding {
    fn new(inputs: usize, gates: usize, output: Option<Tt>, constants: bool) -> Self {
        assert!(gates >= 1, "a gate at least");
        let rows = tt::rows(inputs);
        let mut cnf = Cnf::default();
        let mut value: Vec<Vec<Val>> = (0..inputs)
            .map(|i| {
                let t = tt::input(inputs, i);
                (0..rows).map(|r| Val::Const((t >> r) & 1 == 1)).collect()
            })
            .collect();
        for g in 0..gates {
            let row = (0..rows)
                .map(|r| match output {
                    Some(t) if g + 1 == gates => Val::Const((t >> r) & 1 == 1),
                    _ => Val::Var(cnf.var()),
                })
                .collect();
            value.push(row);
        }

        let mut select: Vec<Vec<Lit>> = Vec::with_capacity(gates);
        for g in 0..gates {
            let node = inputs + g;
            let options = pairs(inputs, g);
            let lits: Vec<Lit> = options.iter().map(|_| cnf.var()).collect();
            cnf.clause(&lits.iter().map(|&l| Val::Var(l)).collect::<Vec<_>>());
            for (&(a, b), &s) in options.iter().zip(&lits) {
                let s = Val::Var(!s);
                for ((&va, &vb), &vg) in value[a].iter().zip(&value[b]).zip(&value[node]) {
                    cnf.clause(&[s, va, vg]);
                    cnf.clause(&[s, vb, vg]);
                    cnf.clause(&[s, !va, !vb, !vg]);
                }
            }
            select.push(lits);
        }

        for g in 1..gates {
            let (before, after) = (pairs(inputs, g - 1), pairs(inputs, g));
            for (p, &(a1, b1)) in before.iter().enumerate() {
                for (q, &(a2, b2)) in after.iter().enumerate() {
                    if (b2, a2) <= (b1, a1) {
                        cnf.clause(&[Val::Var(!select[g - 1][p]), Val::Var(!select[g][q])]);
                    }
                }
            }
        }

        for g in 0..gates {
            let node = inputs + g;
            for i in 0..inputs {
                let differs: Vec<Val> = (0..rows)
                    .map(|r| differ(value[node][r], value[i][r]))
                    .collect();
                cnf.clause(&differs);
            }
            if !constants && (output.is_none() || g + 1 < gates) {
                cnf.clause(&value[node].clone());
                cnf.clause(&value[node].iter().map(|&v| !v).collect::<Vec<_>>());
            }
            for h in g + 1..gates {
                let other = inputs + h;
                let witnesses: Vec<Val> = (0..rows)
                    .map(|r| {
                        let d = Val::Var(cnf.var());
                        let (vg, vh) = (value[node][r], value[other][r]);
                        cnf.clause(&[!d, vg, vh]);
                        cnf.clause(&[!d, !vg, !vh]);
                        d
                    })
                    .collect();
                cnf.clause(&witnesses);
            }
        }
        Encoding {
            cnf,
            inputs,
            gates,
            value,
            select,
        }
    }

    /// The selections of the gates after `g` that read it.
    fn readers(&self, g: usize) -> Vec<Val> {
        let node = self.inputs + g;
        (g + 1..self.gates)
            .flat_map(|h| {
                pairs(self.inputs, h)
                    .into_iter()
                    .zip(self.select[h].clone())
                    .filter(move |&((a, b), _)| a == node || b == node)
                    .map(|(_, s)| Val::Var(s))
            })
            .collect()
    }

    fn solve(self) -> Option<Circuit> {
        let model = self.cnf.solve()?;
        let chosen = (0..self.gates)
            .map(|g| {
                let p = self.select[g].iter().position(|s| model[s.0 as usize])?;
                let (a, b) = pairs(self.inputs, g)[p];
                Some((a as u8, b as u8))
            })
            .collect::<Option<Vec<_>>>()?;
        Some(Circuit {
            inputs: self.inputs,
            output: (self.inputs + self.gates - 1) as u8,
            gates: chosen,
        })
    }
}

/// A circuit of exactly `gates` gates computing `target` at its last gate, every other gate
/// read by a later one; `None` when none exists.
pub fn synthesize(inputs: usize, target: Tt, gates: usize) -> Option<Circuit> {
    let constant = target == 0 || target == tt::mask(inputs);
    let mut e = Encoding::new(inputs, gates, Some(target), constant);
    for g in 0..gates - 1 {
        let readers = e.readers(g);
        e.cnf.clause(&readers);
    }
    e.solve()
}

/// A circuit of exactly `gates` gates holding every one of `targets` (non-constant, not
/// inputs) at some gate, every gate read later or a target: multi-output cost, such as the
/// full adder's sum and carry together. `None` when none exists.
pub fn synthesize_all(inputs: usize, targets: &[Tt], gates: usize) -> Option<Circuit> {
    let rows = tt::rows(inputs);
    let mut e = Encoding::new(inputs, gates, None, false);
    let mut is_target: Vec<Vec<Val>> = vec![Vec::new(); gates];
    for &t in targets {
        let mut somewhere = Vec::new();
        for (g, marks) in is_target.iter_mut().enumerate() {
            let eq = Val::Var(e.cnf.var());
            for r in 0..rows {
                let want = Val::Const((t >> r) & 1 == 1);
                e.cnf.clause(&[!eq, differ(e.value[inputs + g][r], !want)]);
            }
            somewhere.push(eq);
            marks.push(eq);
        }
        e.cnf.clause(&somewhere);
    }
    for (g, marks) in is_target.iter().enumerate() {
        let mut used = e.readers(g);
        used.extend(marks);
        e.cnf.clause(&used);
    }
    let mut c = e.solve()?;
    let tables = c.tables()?;
    c.output = tables.iter().rposition(|t| targets.contains(t))? as u8;
    Some(c)
}

/// A value that holds when `a` and a constant `b` differ on this row; two variables differ
/// only through an auxiliary, so this takes the constant side.
fn differ(a: Val, b: Val) -> Val {
    match b {
        Val::Const(true) => !a,
        Val::Const(false) => a,
        Val::Var(_) => unreachable!("inputs are constants"),
    }
}

/// The cost of `target` above `floor` (no circuit of `floor` gates or fewer computes it, by
/// exhaustion), trying sizes upward to `limit`: the witness and the sizes proven UNSAT.
pub fn minimize(
    inputs: usize,
    target: Tt,
    floor: usize,
    limit: usize,
) -> (Option<Circuit>, Vec<usize>) {
    let mut unsat = Vec::new();
    for k in floor + 1..=limit {
        match synthesize(inputs, target, k) {
            Some(c) => return (Some(c), unsat),
            None => unsat.push(k),
        }
    }
    (None, unsat)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_xor_at_four_and_not_at_three() {
        let xor = 0xC ^ 0xA;
        assert!(synthesize(2, xor, 3).is_none());
        let c = synthesize(2, xor, 4).expect("XOR in 4");
        assert_eq!(c.eval(), Some(xor));
    }

    #[test]
    fn minimize_walks_up_from_the_floor() {
        let maj3 = (0xF0 & 0xCC) | (0xF0 & 0xAA) | (0xCC & 0xAA);
        let (c, unsat) = minimize(3, maj3, 0, 10);
        assert_eq!(c.map(|c| c.cost()), Some(6));
        assert_eq!(unsat, vec![1, 2, 3, 4, 5]);
    }

    #[test]
    fn the_full_adder_is_nine_gates_together() {
        let sum = 0xF0 ^ 0xCC ^ 0xAA;
        let carry = (0xF0 & 0xCC) | (0xF0 & 0xAA) | (0xCC & 0xAA);
        assert!(synthesize_all(3, &[sum, carry], 8).is_none());
        let c = synthesize_all(3, &[sum, carry], 9).expect("the full adder in 9");
        let tables = c.tables().unwrap();
        assert!(tables.contains(&sum) && tables.contains(&carry));
    }

    #[test]
    fn xor_and_equ_together_are_five_gates() {
        let (x, y) = (0xC, 0xA);
        assert!(synthesize_all(2, &[x ^ y, !(x ^ y) & 0xF], 4).is_none());
        assert!(synthesize_all(2, &[x ^ y, !(x ^ y) & 0xF], 5).is_some());
    }

    #[test]
    fn constants_are_synthesized_too() {
        assert_eq!(minimize(3, 0xFF, 0, 5).0.map(|c| c.cost()), Some(2));
        assert_eq!(minimize(3, 0x00, 0, 5).0.map(|c| c.cost()), Some(3));
    }
}
