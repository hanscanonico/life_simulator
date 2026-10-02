//! Exhaustive canonical enumeration: every circuit up to `max_gates` gates whose operand pairs
//! (max, min) strictly increase, gate by gate, and whose every gate computes a function not
//! already present. A minimal circuit computes no function twice (drop the repeat) nor an
//! input, and placing at each step the available gate with the smallest pair orders it so:
//! the gates left behind had larger pairs, and the gates the new node frees have a larger max.
//! So the first gate count at which f appears is f's exact cost, and an f never reached
//! costs more than `max_gates` — the study's method 1 (`docs/studies/topless.md` §1.1).

use crate::circuit::Circuit;
use crate::tt::{self, Tt};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;

pub const UNREACHED: u8 = u8::MAX;

/// Every operand pair over the most nodes searched: 4 inputs and 20 gates.
const MAX_CANDIDATES: usize = 24 * 25 / 2;

/// Costs up to `max_gates`, `UNREACHED` above, and a witness for each reached function.
pub struct Enumeration {
    pub inputs: usize,
    pub max_gates: usize,
    pub cost: Vec<u8>,
    pub witness: Vec<Option<Circuit>>,
    /// Gates placed below the task prefixes, last gates aside: a measure of the work.
    pub placed: u64,
}

/// One worker's search state. `found[f]` is the task whose circuit is f's witness: on equal
/// cost the lower task wins, so the result does not depend on how tasks met threads.
///
/// `sinks` marks the gates no later gate reads. A gate consumes at most two sinks and is one,
/// so their count falls by one a gate at most; a minimal circuit ends on a single sink, its
/// output, so a prefix holding more sinks than the gates left can absorb is cut, and a
/// function is recorded only where it is the one sink.
struct Search {
    mask: Tt,
    max_gates: usize,
    nodes: Vec<Tt>,
    pairs: Vec<(u8, u8)>,
    sinks: u32,
    present: Vec<u64>,
    best: Vec<u8>,
    found: Vec<u32>,
    witness: Vec<Vec<(u8, u8)>>,
    task: u32,
    placed: u64,
}

impl Search {
    fn new(inputs: usize, max_gates: usize) -> Self {
        let n = tt::functions(inputs);
        let mut search = Search {
            mask: tt::mask(inputs),
            max_gates,
            nodes: Vec::new(),
            pairs: Vec::new(),
            sinks: 0,
            present: vec![0; n.div_ceil(64)],
            best: vec![UNREACHED; n],
            found: vec![u32::MAX; n],
            witness: vec![Vec::new(); n],
            task: 0,
            placed: 0,
        };
        for i in 0..inputs {
            let f = tt::input(inputs, i);
            search.nodes.push(f);
            search.set(f, true);
            search.best[f as usize] = 0;
        }
        search
    }

    fn has(&self, f: Tt) -> bool {
        self.present[(f >> 6) as usize] >> (f & 63) & 1 == 1
    }

    fn set(&mut self, f: Tt, on: bool) {
        let word = &mut self.present[(f >> 6) as usize];
        if on {
            *word |= 1 << (f & 63);
        } else {
            *word &= !(1 << (f & 63));
        }
    }

    /// The sinks once a gate reading `a` and `b` is placed as node `n`.
    fn sinks_after(&self, a: usize, b: usize, n: usize) -> u32 {
        self.sinks & !(1 << a | 1 << b) | 1 << n
    }

    /// Records f at `g` gates when its circuit, `pairs` then `pair`, beats the one held.
    fn record(&mut self, f: Tt, g: u8, pair: (u8, u8)) {
        let slot = f as usize;
        if g < self.best[slot] || (g == self.best[slot] && self.task < self.found[slot]) {
            self.best[slot] = g;
            self.found[slot] = self.task;
            self.witness[slot].clone_from(&self.pairs);
            self.witness[slot].push(pair);
        }
    }

    /// Places the gate `pair` computing f, recording f if it is the one sink. Returns the
    /// sinks before, for `pop`.
    fn push(&mut self, pair: (u8, u8), f: Tt) -> u32 {
        let n = self.nodes.len();
        let before = self.sinks;
        let after = self.sinks_after(pair.0 as usize, pair.1 as usize, n);
        if after.count_ones() == 1 {
            self.record(f, self.pairs.len() as u8 + 1, pair);
        }
        self.nodes.push(f);
        self.pairs.push(pair);
        self.set(f, true);
        self.sinks = after;
        before
    }

    fn pop(&mut self, sinks: u32) {
        let f = self.nodes.pop().expect("a gate to pop");
        self.pairs.pop();
        self.set(f, false);
        self.sinks = sinks;
    }

    /// Fills `out` with the pairs open to the next gate: canonically after the last one, and
    /// consuming enough sinks that no more are left than the gates still allowed can absorb.
    /// Returns how many.
    fn candidates(&self, out: &mut [(u8, u8); MAX_CANDIDATES]) -> usize {
        let n = self.nodes.len();
        let room = (self.max_gates - self.pairs.len()) as i32;
        let required = self.sinks.count_ones() as i32 + 1 - room;
        let (b0, a0) = self
            .pairs
            .last()
            .map_or((0, 0), |&(a, b)| (b as usize, a as usize + 1));
        let canonical = |a: usize, b: usize| b > b0 || (b == b0 && a >= a0);
        let sink = |node: usize| self.sinks >> node & 1 == 1;
        let mut len = 0;
        let mut take = |a: usize, b: usize| {
            if canonical(a, b) {
                out[len] = (a as u8, b as u8);
                len += 1;
            }
        };
        match required {
            ..=0 => (0..n).for_each(|b| (0..=b).for_each(|a| take(a, b))),
            1 => {
                for p in (0..n).filter(|&p| sink(p)) {
                    (0..=p)
                        .filter(|&a| a == p || !sink(a))
                        .for_each(|a| take(a, p));
                    (p + 1..n).for_each(|b| take(p, b));
                }
            }
            2 => {
                for b in (0..n).filter(|&b| sink(b)) {
                    (0..b).filter(|&a| sink(a)).for_each(|a| take(a, b));
                }
            }
            _ => {}
        }
        len
    }

    /// The last gate must leave one sink: it reads both sinks, or the one sink and any node.
    /// The same pairs as `candidates`, in the same order, with nothing pushed.
    fn last_gate(&mut self, g: usize) {
        let n = self.nodes.len();
        let (b0, a0) = self
            .pairs
            .last()
            .map_or((0, 0), |&(a, b)| (b as usize, a as usize + 1));
        let canonical = |a: usize, b: usize| b > b0 || (b == b0 && a >= a0);
        let first = self.sinks.trailing_zeros() as usize;
        let try_pair = |search: &mut Search, a: usize, b: usize| {
            if canonical(a, b) {
                let f = !(search.nodes[a] & search.nodes[b]) & search.mask;
                if !search.has(f) {
                    search.record(f, g as u8, (a as u8, b as u8));
                }
            }
        };
        match self.sinks.count_ones() {
            1 => (0..n).for_each(|x| try_pair(self, x.min(first), x.max(first))),
            2 => try_pair(self, first, 31 - self.sinks.leading_zeros() as usize),
            _ => {}
        }
    }

    /// Places every open next gate and recurses while gates are left.
    fn dfs(&mut self) {
        if self.pairs.len() >= self.max_gates {
            return;
        }
        let n = self.nodes.len();
        let g = self.pairs.len() + 1;
        if g == self.max_gates && self.sinks != 0 {
            self.last_gate(g);
            return;
        }
        let mut open = [(0, 0); MAX_CANDIDATES];
        let len = self.candidates(&mut open);
        for &(a, b) in &open[..len] {
            let (a, b) = (a as usize, b as usize);
            let f = !(self.nodes[a] & self.nodes[b]) & self.mask;
            if self.has(f) {
                continue;
            }
            let after = self.sinks_after(a, b, n);
            if after.count_ones() == 1 {
                self.record(f, g as u8, (a as u8, b as u8));
            }
            if g < self.max_gates {
                let before = self.sinks;
                self.nodes.push(f);
                self.pairs.push((a as u8, b as u8));
                self.set(f, true);
                self.sinks = after;
                self.placed += 1;
                self.dfs();
                self.pop(before);
            }
        }
    }
}

/// Gates placed before the work is split: the canonical prefixes of this many gates are the
/// tasks, enough of them to keep every worker busy.
const PREFIX_GATES: usize = 7;

/// Every canonical prefix of `depth` gates the sink bound lets through and, with `reduce`,
/// [`least_image`] keeps (a prefix it rejects has no extension it keeps), recording the
/// circuits of up to `depth` gates on the way.
fn prefixes(search: &mut Search, depth: usize, reduce: bool, out: &mut Vec<Vec<(u8, u8)>>) {
    if search.pairs.len() == depth {
        out.push(search.pairs.clone());
        return;
    }
    let mut open = [(0, 0); MAX_CANDIDATES];
    let len = search.candidates(&mut open);
    for &(a, b) in &open[..len] {
        let (a, b) = (a as usize, b as usize);
        let f = !(search.nodes[a] & search.nodes[b]) & search.mask;
        if search.has(f) {
            continue;
        }
        let before = search.push((a as u8, b as u8), f);
        let inputs = search.nodes.len() - search.pairs.len();
        if !reduce || least_image(inputs, &search.pairs) {
            prefixes(search, depth, reduce, out);
        }
        search.pop(before);
    }
}

/// Whether a task's prefix can open the least of its circuit's input-permutation images, the
/// one whose canonical gate sequence is lexicographically least. For each permutation τ, the
/// τ-images of the prefix's gates are a sub-circuit of τ's image; ordered greedily they give a
/// sequence that the image's own canonical sequence can only undercut (a greedy choice over
/// more gates is never larger). So an ordered image below the prefix means this circuit is
/// not the least and is skipped. Costs are permutation-invariant and the least image is
/// canonical too, so enumerating the surviving prefixes still reaches every class at its cost.
fn least_image(inputs: usize, prefix: &[(u8, u8)]) -> bool {
    let key = |a: usize, b: usize| (a.max(b), a.min(b));
    let own: Vec<(usize, usize)> = prefix
        .iter()
        .map(|&(a, b)| key(a as usize, b as usize))
        .collect();
    tt::permutations(inputs).iter().all(|perm| {
        let mut position: Vec<Option<usize>> = vec![None; prefix.len()];
        for (step, &mine) in own.iter().enumerate() {
            let node = |n: u8| {
                let n = n as usize;
                if n < inputs {
                    Some(perm[n])
                } else {
                    position[n - inputs].map(|p| inputs + p)
                }
            };
            let (gate, least) = prefix
                .iter()
                .enumerate()
                .filter(|&(j, _)| position[j].is_none())
                .filter_map(|(j, &(a, b))| Some((j, key(node(a)?, node(b)?))))
                .min_by_key(|&(_, k)| k)
                .expect("a sub-circuit always has an available gate");
            if least != mine {
                return least > mine;
            }
            position[gate] = Some(step);
        }
        true
    })
}

/// Enumerates every canonical circuit of up to `max_gates` gates on `threads` workers, or,
/// with `reduce`, only the prefixes [`least_image`] keeps, then gives each
/// function its class's least cost and the permuted witness.
pub fn enumerate(inputs: usize, max_gates: usize, threads: usize, reduce: bool) -> Enumeration {
    let mut merged = Search::new(inputs, max_gates);
    let mut tasks = Vec::new();
    prefixes(&mut merged, max_gates.min(PREFIX_GATES), reduce, &mut tasks);
    if max_gates > PREFIX_GATES {
        let next = AtomicUsize::new(0);
        let results = Mutex::new(Vec::new());
        std::thread::scope(|scope| {
            for _ in 0..threads.max(1) {
                scope.spawn(|| {
                    let mut search = Search::new(inputs, max_gates);
                    loop {
                        let i = next.fetch_add(1, Ordering::Relaxed);
                        let Some(prefix) = tasks.get(i) else { break };
                        search.task = i as u32 + 1;
                        let mut restore = Vec::new();
                        for &(a, b) in prefix {
                            let f = !(search.nodes[a as usize] & search.nodes[b as usize])
                                & search.mask;
                            restore.push(search.push((a, b), f));
                        }
                        search.dfs();
                        for before in restore.into_iter().rev() {
                            search.pop(before);
                        }
                    }
                    results.lock().expect("no worker panicked").push(search);
                });
            }
        });
        for worker in results.into_inner().expect("no worker panicked") {
            merged.placed += worker.placed;
            for f in 0..merged.best.len() {
                let (g, task) = (worker.best[f], worker.found[f]);
                if g < merged.best[f]
                    || (g == merged.best[f] && g != UNREACHED && task < merged.found[f])
                {
                    merged.best[f] = g;
                    merged.found[f] = task;
                    merged.witness[f].clone_from(&worker.witness[f]);
                }
            }
        }
    }
    let mut witness: Vec<Option<Circuit>> = (0..merged.best.len())
        .map(|f| {
            let g = merged.best[f];
            if g == UNREACHED {
                return None;
            }
            if g == 0 {
                let i = (0..inputs).find(|&i| tt::input(inputs, i) as usize == f)?;
                return Some(Circuit {
                    inputs,
                    gates: Vec::new(),
                    output: i as u8,
                });
            }
            let gates = merged.witness[f].clone();
            Some(Circuit {
                inputs,
                output: (inputs + gates.len() - 1) as u8,
                gates,
            })
        })
        .collect();
    let mut cost = merged.best;
    if reduce {
        spread_over_classes(inputs, &mut cost, &mut witness);
    }
    Enumeration {
        inputs,
        max_gates,
        cost,
        witness,
        placed: merged.placed,
    }
}

/// Gives every function its class's least cost, witnessed by the least member reaching it,
/// permuted.
fn spread_over_classes(inputs: usize, cost: &mut [u8], witness: &mut [Option<Circuit>]) {
    let reps = tt::class_representatives(inputs);
    let mut cheapest: std::collections::HashMap<Tt, usize> = std::collections::HashMap::new();
    for f in 0..cost.len() {
        let best = cheapest.entry(reps[f]).or_insert(f);
        if cost[f] < cost[*best] {
            *best = f;
        }
    }
    for f in 0..cost.len() {
        let member = cheapest[&reps[f]];
        if member == f || cost[member] == UNREACHED {
            continue;
        }
        let perm = tt::permutation_to(inputs, member as Tt, f as Tt).expect("same class");
        cost[f] = cost[member];
        witness[f] = witness[member].as_ref().map(|w| w.permuted(&perm));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn two_input_costs_are_the_ladder_s() {
        let e = enumerate(2, 8, 2, false);
        let (x, y) = (0xC, 0xA);
        let cost = |f: Tt| e.cost[f as usize];
        assert_eq!(cost(x), 0);
        assert_eq!(cost(!x & 0xF), 1);
        assert_eq!(cost(!(x & y) & 0xF), 1);
        assert_eq!(cost(x & y), 2);
        assert_eq!(cost(x | y), 3);
        assert_eq!(cost(!(x | y) & 0xF), 4);
        assert_eq!(cost(x ^ y), 4);
        assert_eq!(cost(!(x ^ y) & 0xF), 5);
        assert_eq!(cost(0xF), 2);
        assert_eq!(cost(0x0), 3);
        assert!(e.cost.iter().all(|&c| c != UNREACHED));
    }

    #[test]
    fn every_witness_computes_its_function_at_its_cost() {
        let e = enumerate(3, 6, 4, false);
        for f in 0..256 {
            if let Some(w) = &e.witness[f] {
                assert_eq!(w.eval(), Some(f as Tt), "witness of {f:02X}");
                assert_eq!(w.cost(), e.cost[f] as usize);
            } else {
                assert_eq!(e.cost[f], UNREACHED);
            }
        }
    }

    #[test]
    fn the_result_does_not_depend_on_the_thread_count() {
        let one = enumerate(3, 6, 1, false);
        let many = enumerate(3, 6, 5, false);
        assert_eq!(one.cost, many.cost);
        assert_eq!(one.witness, many.witness);
    }

    #[test]
    fn the_symmetry_reduction_keeps_every_cost() {
        let full = enumerate(3, 10, 4, false);
        let reduced = enumerate(3, 10, 4, true);
        assert_eq!(full.cost, reduced.cost);
        for f in 0..256 {
            let w = reduced.witness[f]
                .as_ref()
                .expect("every function within 10");
            assert_eq!(w.eval(), Some(f as Tt));
            assert_eq!(w.cost(), reduced.cost[f] as usize);
        }
        let full4 = enumerate(4, 7, 4, false);
        let reduced4 = enumerate(4, 7, 4, true);
        assert_eq!(full4.cost, reduced4.cost);
    }
}
