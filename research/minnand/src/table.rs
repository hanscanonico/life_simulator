//! The cost table of every function of `inputs` inputs and a witness circuit per class: built
//! by enumeration to some gate count, then closed by SAT per class above it; written as one
//! byte a function, one line a class, and one line a SAT-proven class in the proof log.

use crate::circuit::Circuit;
use crate::enumerate::{self, UNREACHED};
use crate::sat;
use crate::tt::{self, Tt};
use std::collections::BTreeMap;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{mpsc, Arc};
use std::time::Instant;

/// A byte with this bit set is a lower bound, `≥ (byte & !AT_LEAST)`, the class's cost left
/// open past every size searched; without it the byte is the exact cost.
pub const AT_LEAST: u8 = 0x80;

pub struct Table {
    pub inputs: usize,
    pub cost: Vec<u8>,
    /// One witness per class whose cost is exact, keyed by its representative.
    pub witness: BTreeMap<Tt, Circuit>,
    /// Each function's class representative.
    reps: Vec<Tt>,
}

/// How one class's cost was proven above the enumeration: the sizes found UNSAT, then the
/// size found SAT, if any. One line of the proof log.
#[derive(Clone, Debug, PartialEq)]
pub struct Proof {
    pub class: Tt,
    pub unsat: Vec<usize>,
    pub witness: Option<Circuit>,
    pub seconds: f64,
}

impl Proof {
    pub fn line(&self) -> String {
        let unsat: Vec<String> = self.unsat.iter().map(usize::to_string).collect();
        let unsat = if unsat.is_empty() {
            "-".to_string()
        } else {
            unsat.join(",")
        };
        let witness = self
            .witness
            .as_ref()
            .map_or("-".to_string(), Circuit::encode);
        format!("{:04x} {unsat} {witness} {:.1}", self.class, self.seconds)
    }

    pub fn parse(inputs: usize, line: &str) -> Option<Proof> {
        let fields: Vec<&str> = line.split(' ').collect();
        let [class, unsat, witness, seconds] = fields[..] else {
            return None;
        };
        let unsat = match unsat {
            "-" => Vec::new(),
            list => list
                .split(',')
                .map(|k| k.parse().ok())
                .collect::<Option<_>>()?,
        };
        let witness = match witness {
            "-" => None,
            text => Some(Circuit::decode(inputs, text)?),
        };
        Some(Proof {
            class: Tt::from_str_radix(class, 16).ok()?,
            unsat,
            witness,
            seconds: seconds.parse().ok()?,
        })
    }
}

/// The proof log's first line, then the enumeration's gate count.
pub const PROOF_HEADER: &str = "# exhaustive enumeration to gates: ";

/// The proof log: the enumeration's reach, then one proof a line in any order; a class run
/// again from a later bound has its lines merged in order.
pub struct Proofs {
    pub enumerated: usize,
    pub lines: Vec<Proof>,
}

pub fn parse_proofs(inputs: usize, text: &str) -> Result<Proofs, String> {
    let mut lines = text.lines();
    let header = lines.next().unwrap_or_default();
    let enumerated = header
        .strip_prefix(PROOF_HEADER)
        .and_then(|g| g.parse().ok())
        .ok_or(format!("bad proof log header {header:?}"))?;
    let mut merged: BTreeMap<Tt, Proof> = BTreeMap::new();
    for line in lines.filter(|l| !l.starts_with('#') && !l.is_empty()) {
        let proof = Proof::parse(inputs, line).ok_or(format!("bad proof line {line:?}"))?;
        match merged.get_mut(&proof.class) {
            Some(earlier) => {
                earlier.unsat.extend(proof.unsat);
                earlier.witness = proof.witness;
                earlier.seconds += proof.seconds;
            }
            None => {
                merged.insert(proof.class, proof);
            }
        }
    }
    let lines = merged.into_values().collect();
    Ok(Proofs { enumerated, lines })
}

impl Proofs {
    /// Every class costing more than the enumeration reached, or left open, has its sizes
    /// from the enumeration's bound to its cost (or bound) proven UNSAT on the log, and its
    /// witness there; no class at or below the reach has a proof line.
    pub fn check(&self, table: &Table) -> Result<(), String> {
        let by_class: BTreeMap<Tt, &Proof> = self.lines.iter().map(|p| (p.class, p)).collect();
        for class in table.classes() {
            let byte = table.cost[class as usize];
            let (bound, exact) = (byte & !AT_LEAST, byte & AT_LEAST == 0);
            let proof = by_class.get(&class);
            if exact && bound as usize <= self.enumerated {
                if proof.is_some() {
                    return Err(format!(
                        "class {class:04x} is within the enumeration yet has a proof"
                    ));
                }
                continue;
            }
            let proof = match proof {
                Some(p) => p,
                None if !exact && bound as usize == self.enumerated + 1 => continue,
                None => {
                    return Err(format!(
                        "class {class:04x}: cost {bound} with no proof line"
                    ))
                }
            };
            let unsat: Vec<usize> = (self.enumerated + 1..bound as usize).collect();
            if proof.unsat != unsat {
                return Err(format!(
                    "class {class:04x}: UNSAT at {:?}, expected {unsat:?}",
                    proof.unsat
                ));
            }
            if exact && proof.witness.as_ref() != table.witness.get(&class) {
                return Err(format!(
                    "class {class:04x}: the log's witness is not the table's"
                ));
            }
        }
        Ok(())
    }
}

impl Table {
    /// The exhaustive enumeration to `gates`: exact to it, `≥ gates + 1` above.
    pub fn enumerate(inputs: usize, gates: usize, threads: usize) -> Table {
        let e = enumerate::enumerate(inputs, gates, threads, true);
        eprintln!(
            "{} inputs to {gates} gates: {} gates placed",
            inputs, e.placed
        );
        let floor = AT_LEAST | (gates as u8 + 1);
        let cost = e
            .cost
            .iter()
            .map(|&c| if c == UNREACHED { floor } else { c })
            .collect();
        let witness = tt::classes(inputs)
            .into_iter()
            .filter_map(|c| e.witness[c as usize].clone().map(|w| (c, w)))
            .collect();
        Table {
            inputs,
            cost,
            witness,
            reps: tt::class_representatives(inputs),
        }
    }

    /// The class representatives, ascending.
    pub fn classes(&self) -> impl Iterator<Item = Tt> + '_ {
        (0..self.reps.len())
            .filter(|&f| self.reps[f] == f as Tt)
            .map(|f| f as Tt)
    }

    /// The classes whose cost is still a lower bound, with that bound.
    pub fn open(&self) -> Vec<(Tt, usize)> {
        self.classes()
            .filter(|&c| self.cost[c as usize] & AT_LEAST != 0)
            .map(|c| (c, (self.cost[c as usize] & !AT_LEAST) as usize))
            .collect()
    }

    /// Applies a proof: each size it found UNSAT must be the class's next lower bound. Sizes
    /// below the bound, and a proof for a class already exact by it, were applied before.
    pub fn apply(&mut self, proof: &Proof) -> Result<(), String> {
        let class = proof.class;
        let byte = self.cost[class as usize];
        if byte & AT_LEAST == 0 {
            return match &proof.witness {
                Some(w) if self.witness.get(&class) == Some(w) => Ok(()),
                _ => Err(format!("class {class:04x} is already exact")),
            };
        }
        let start = (byte & !AT_LEAST) as usize;
        let mut bound = start;
        for &k in proof.unsat.iter().filter(|&&k| k >= start) {
            if k != bound {
                return Err(format!(
                    "class {class:04x}: UNSAT at {k} leaves {bound} unproven"
                ));
            }
            bound += 1;
        }
        let byte = match &proof.witness {
            Some(w) if w.cost() == bound && w.eval() == Some(class) => {
                self.witness.insert(class, w.clone());
                bound as u8
            }
            Some(_) => {
                return Err(format!(
                    "class {class:04x}: the witness is not a {bound}-gate circuit for it"
                ))
            }
            None => AT_LEAST | bound as u8,
        };
        for (f, cost) in self.cost.iter_mut().enumerate() {
            if self.reps[f] == class {
                *cost = byte;
            }
        }
        Ok(())
    }

    /// Circuits at open classes' bounds found by extending the exact classes' witnesses by
    /// one or two gates: each such circuit proves its class costs exactly its bound, with no
    /// SAT. A proof per class found, in class order.
    pub fn extend(&self) -> Vec<Proof> {
        let start = Instant::now();
        let inputs = self.inputs;
        let reps = &self.reps;
        let bounds: BTreeMap<Tt, usize> = self.open().into_iter().collect();
        let mut found: BTreeMap<Tt, Circuit> = BTreeMap::new();
        let mut consider = |w: &Circuit, added: &[(u8, u8)], f: Tt| {
            let rep = reps[f as usize];
            if bounds.get(&rep) == Some(&(w.cost() + added.len())) && !found.contains_key(&rep) {
                let mut c = w.clone();
                c.gates.extend_from_slice(added);
                c.output = (inputs + c.cost() - 1) as u8;
                let perm = tt::permutation_to(inputs, f, rep).expect("same class");
                found.insert(rep, c.permuted(&perm));
            }
        };
        let wanted: Vec<usize> = bounds.values().copied().collect();
        for w in self.witness.values() {
            let mut nodes = w.tables().expect("a well-formed witness");
            let n = nodes.len();
            let pairs = |n: usize| (0..n).flat_map(|b| (0..=b).map(move |a| (a, b)));
            for (a, b) in pairs(n) {
                let h = tt::nand(inputs, nodes[a], nodes[b]);
                let first = (a as u8, b as u8);
                if wanted.contains(&(w.cost() + 1)) {
                    consider(w, &[first], h);
                }
                if wanted.contains(&(w.cost() + 2)) {
                    nodes.push(h);
                    for (c, d) in pairs(n + 1) {
                        let f = tt::nand(inputs, nodes[c], nodes[d]);
                        consider(w, &[first, (c as u8, d as u8)], f);
                    }
                    nodes.pop();
                }
            }
        }
        let seconds = start.elapsed().as_secs_f64() / found.len().max(1) as f64;
        found
            .into_iter()
            .map(|(class, witness)| Proof {
                class,
                unsat: Vec::new(),
                witness: Some(witness),
                seconds,
            })
            .collect()
    }

    /// Runs SAT on each open class from its bound up to `limit` gates on `threads` workers,
    /// handing each proof to `done` (the log) and applying it as it lands. Past `deadline`
    /// it stops waiting and returns how many classes it left unfinished; their workers keep
    /// running until the process exits.
    pub fn close(
        &mut self,
        limit: usize,
        threads: usize,
        deadline: Option<Instant>,
        done: &mut dyn FnMut(&Proof),
    ) -> Result<usize, String> {
        let open: Vec<(Tt, usize)> = self
            .open()
            .into_iter()
            .filter(|&(_, bound)| bound <= limit)
            .collect();
        let open = Arc::new(open);
        let inputs = self.inputs;
        let next = Arc::new(AtomicUsize::new(0));
        let (send, receive) = mpsc::channel();
        for _ in 0..threads.max(1) {
            let (open, next, send) = (Arc::clone(&open), Arc::clone(&next), send.clone());
            std::thread::spawn(move || loop {
                let i = next.fetch_add(1, Ordering::Relaxed);
                let Some(&(class, bound)) = open.get(i) else {
                    break;
                };
                let start = Instant::now();
                let (witness, unsat) = sat::minimize(inputs, class, bound - 1, limit);
                let seconds = start.elapsed().as_secs_f64();
                if send
                    .send(Proof {
                        class,
                        unsat,
                        witness,
                        seconds,
                    })
                    .is_err()
                {
                    break;
                }
            });
        }
        drop(send);
        let mut left = open.len();
        while left > 0 {
            let proof = match deadline {
                Some(d) => {
                    match receive.recv_timeout(d.saturating_duration_since(Instant::now())) {
                        Ok(p) => p,
                        Err(_) => break,
                    }
                }
                None => receive.recv().map_err(|e| e.to_string())?,
            };
            done(&proof);
            self.apply(&proof)?;
            left -= 1;
        }
        Ok(left)
    }

    pub fn bytes(&self) -> &[u8] {
        &self.cost
    }

    pub fn witness_text(&self) -> String {
        let width = tt::rows(self.inputs) / 4;
        let mut out = format!(
            "# minimal NAND witness per input-permutation class, {n} inputs: class cost circuit\n\
             # circuit: the output node, then each gate's two operands, one character a node\n\
             # (0-9, a-z): node i < {n} is input i, node {n} + j is gate j\n",
            n = self.inputs
        );
        for (class, w) in &self.witness {
            out += &format!("{class:0width$x} {} {}\n", w.cost(), w.encode());
        }
        out
    }

    /// Reads a table back from its byte file and witness file.
    pub fn parse(inputs: usize, bytes: &[u8], witnesses: &str) -> Result<Table, String> {
        if bytes.len() != tt::functions(inputs) {
            return Err(format!(
                "{} bytes, expected {}",
                bytes.len(),
                tt::functions(inputs)
            ));
        }
        let mut witness = BTreeMap::new();
        for line in witnesses
            .lines()
            .filter(|l| !l.starts_with('#') && !l.is_empty())
        {
            let fields: Vec<&str> = line.split(' ').collect();
            let [class, cost, circuit] = fields[..] else {
                return Err(format!("bad line {line:?}"));
            };
            let class = Tt::from_str_radix(class, 16).map_err(|e| format!("{line:?}: {e}"))?;
            let circuit =
                Circuit::decode(inputs, circuit).ok_or(format!("bad circuit in {line:?}"))?;
            if cost.parse::<usize>().ok() != Some(circuit.cost()) {
                return Err(format!("{line:?}: cost and circuit disagree"));
            }
            witness.insert(class, circuit);
        }
        Ok(Table {
            inputs,
            cost: bytes.to_vec(),
            witness,
            reps: tt::class_representatives(inputs),
        })
    }

    /// Every class has a witness computing its representative at the table's cost, and every
    /// member costs the same and is computed by the permuted witness. The lower bounds are not
    /// re-proven here: that is `Table::build` again.
    pub fn check_witnesses(&self) -> Result<(), String> {
        for f in 0..tt::functions(self.inputs) {
            let rep = self.reps[f];
            let cost = self.cost[f];
            if cost != self.cost[rep as usize] {
                return Err(format!(
                    "{f:04x} costs {cost}, its class {rep:04x} {}",
                    self.cost[rep as usize]
                ));
            }
            if cost & AT_LEAST != 0 {
                continue;
            }
            let w = self
                .witness
                .get(&rep)
                .ok_or(format!("no witness for class {rep:04x}"))?;
            if w.cost() != cost as usize {
                return Err(format!(
                    "class {rep:04x}: witness of {} gates, cost {cost}",
                    w.cost()
                ));
            }
            let perm = tt::permutation_to(self.inputs, rep, f as Tt).ok_or("not a class member")?;
            if w.permuted(&perm).eval() != Some(f as Tt) {
                return Err(format!(
                    "{f:04x}: the permuted witness of {rep:04x} computes something else"
                ));
            }
        }
        Ok(())
    }

    /// The number of functions at each cost byte, lower bounds last.
    pub fn distribution(&self) -> BTreeMap<u8, usize> {
        let mut out = BTreeMap::new();
        for &c in &self.cost {
            *out.entry(c).or_insert(0) += 1;
        }
        out
    }
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    Sha256::digest(bytes)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const XOR3: Tt = 0xF0 ^ 0xCC ^ 0xAA;

    #[test]
    fn a_proof_line_reads_back() {
        let proof = Proof {
            class: 0x0116,
            unsat: vec![11, 12],
            witness: sat::synthesize(3, XOR3, 8),
            seconds: 1.5,
        };
        assert_eq!(Proof::parse(3, &proof.line()), Some(proof));
        assert_eq!(
            Proof::parse(3, "0001 - - 0.0").unwrap().line(),
            "0001 - - 0.0"
        );
    }

    #[test]
    fn proofs_raise_the_bound_then_close_the_class() {
        let mut t = Table::enumerate(3, 6, 2);
        let class = tt::class_representatives(3)[XOR3 as usize];
        assert_eq!(t.cost[XOR3 as usize], AT_LEAST | 7);
        let gap = Proof {
            class,
            unsat: vec![8],
            witness: None,
            seconds: 0.0,
        };
        assert!(t.apply(&gap).is_err());
        let seven = Proof {
            class,
            unsat: vec![7],
            witness: None,
            seconds: 0.0,
        };
        t.apply(&seven).unwrap();
        assert_eq!(t.cost[XOR3 as usize], AT_LEAST | 8);
        let again = Proof {
            class,
            unsat: vec![7],
            witness: sat::synthesize(3, class, 8),
            seconds: 0.0,
        };
        t.apply(&again).unwrap();
        assert_eq!(t.cost[XOR3 as usize], 8);
        assert!(t.apply(&again).is_ok(), "a proof applied twice is a no-op");
    }

    #[test]
    fn the_log_merges_a_class_run_twice() {
        let log = format!(
            "{PROOF_HEADER}6\n0096 7 - 1.0\n0096 - {} 2.0\n",
            sat::synthesize(3, XOR3, 8).unwrap().encode()
        );
        let proofs = parse_proofs(3, &log).unwrap();
        assert_eq!(proofs.enumerated, 6);
        assert_eq!(proofs.lines.len(), 1);
        assert_eq!(proofs.lines[0].unsat, vec![7]);
        assert_eq!(proofs.lines[0].witness.as_ref().map(Circuit::cost), Some(8));
        let mut t = Table::enumerate(3, 6, 2);
        t.apply(&proofs.lines[0]).unwrap();
        proofs.check(&t).unwrap_or_else(|e| panic!("{e}"));
    }
}
