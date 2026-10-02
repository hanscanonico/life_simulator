//! Reading (b): how far one tape sits from another, and the substitution search the design
//! study measured with (`docs/studies/meta-stack.md` §2.4 and §7.3, its `deeppaths`).
//!
//! A path is a sequence of single substitutions. It is **credited** when every step earns
//! more paid units than the one before — on all six fixed sets, at the run's floor — and
//! **neutral or better** when no tape along it earns less than the start.

use crate::score::{par_map, Rungs, Scorer};
use crate::tape::{hamming, levenshtein, ALPHABET};
use std::fmt::Write;

/// The most positions a lattice is built over: 2^16 tapes, each assayed on six sets.
pub const LATTICE_MAX: usize = 16;

/// The orders of one path: whether some order is credited, and whether some order is
/// neutral or better, each with the paid units along it.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Orders {
    pub credited: Option<Vec<u32>>,
    pub neutral: Option<Vec<u32>>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Distance {
    /// Substitutions between two tapes of one length; `None` across lengths.
    pub substitutions: Option<usize>,
    pub edits: usize,
    /// The lattice over the differing positions, where there are at most `LATTICE_MAX`.
    pub orders: Option<Orders>,
}

/// The distance from `a` to `b`, and over every order of the substitutions between them,
/// whether one is credited or neutral or better.
pub fn distance(a: &[u8], b: &[u8], scorer: &Scorer) -> Distance {
    let substitutions = hamming(a, b);
    let orders = substitutions.filter(|d| *d <= LATTICE_MAX).map(|_| {
        let sites: Vec<(usize, u8)> = (0..a.len())
            .filter(|at| a[*at] != b[*at])
            .map(|at| (at, b[at]))
            .collect();
        lattice(a, &sites, scorer)
    });
    Distance {
        substitutions,
        edits: levenshtein(a, b),
        orders,
    }
}

/// Every subset of `sites` applied to `start`, assayed once, then the best chain through
/// them: a subset reached from the start by adding one site at a time.
fn lattice(start: &[u8], sites: &[(usize, u8)], scorer: &Scorer) -> Orders {
    let subsets: Vec<usize> = (0..1usize << sites.len()).collect();
    let units = par_map(&subsets, |subset| {
        let mut tape = start.to_vec();
        for (bit, (at, byte)) in sites.iter().enumerate() {
            if subset & (1 << bit) != 0 {
                tape[*at] = *byte;
            }
        }
        scorer.paid_units(&tape)
    });
    Orders {
        credited: chain(&units, sites.len(), |from, to| to > from),
        neutral: chain(&units, sites.len(), |_, to| to >= units[0]),
    }
}

/// A chain of subsets from the empty one to the full one, one site added a step, every
/// step allowed by `step`; the units along it.
fn chain(units: &[u32], sites: usize, step: impl Fn(u32, u32) -> bool) -> Option<Vec<u32>> {
    let full = (1usize << sites) - 1;
    let mut reached_from: Vec<Option<usize>> = vec![None; full + 1];
    reached_from[0] = Some(0);
    for subset in 0..=full {
        if reached_from[subset].is_none() {
            continue;
        }
        for bit in 0..sites {
            let next = subset | 1 << bit;
            if next != subset && reached_from[next].is_none() && step(units[subset], units[next]) {
                reached_from[next] = Some(subset);
            }
        }
    }
    reached_from[full]?;
    let mut path = vec![units[full]];
    let mut at = full;
    while at != 0 {
        at = reached_from[at].expect("every subset on the chain was reached");
        path.push(units[at]);
    }
    path.reverse();
    Some(path)
}

/// One substitution: the position and the byte written there.
pub type Edit = (usize, u8);

pub struct Search {
    pub start_units: u32,
    pub start_rungs: Rungs,
    pub screened: u64,
    /// Per k from 1, the mutants credited a target rung on all six sets, with their orders.
    pub hits: Vec<Vec<(Vec<Edit>, Orders)>>,
}

impl Search {
    /// The fewest substitutions to a target rung, by any path.
    pub fn shortest(&self) -> Option<usize> {
        self.hits
            .iter()
            .position(|hits| !hits.is_empty())
            .map(|k| k + 1)
    }

    /// The fewest substitutions to a target rung along a credited path.
    pub fn shortest_credited(&self) -> Option<usize> {
        self.hits
            .iter()
            .position(|hits| hits.iter().any(|(_, orders)| orders.credited.is_some()))
            .map(|k| k + 1)
    }
}

/// Every set of 1 to `k` substitutions over `ALPHABET` at distinct positions inside the
/// first `window` bytes of `start`, and the mutants credited a rung of `target` on all six
/// sets, each with its orders. Exhaustive, as the study searched (k ≤ 3).
pub fn search(start: &[u8], scorer: &Scorer, window: usize, k: usize, target: Rungs) -> Search {
    let window = window.min(start.len());
    let tops: Vec<usize> = (0..window).collect();
    let per_top = par_map(&tops, |top| {
        let mut found: Vec<Vec<Edit>> = Vec::new();
        let mut screened = 0u64;
        let mut tape = start.to_vec();
        let mut edits = Vec::with_capacity(k);
        for byte in ALPHABET {
            if byte == start[*top] {
                continue;
            }
            tape[*top] = byte;
            edits.push((*top, byte));
            below(
                &mut tape,
                start,
                *top,
                k - 1,
                &mut edits,
                &mut |mutant, edits| {
                    screened += 1;
                    if scorer.on_set(mutant, 0).meets(target) && scorer.solid(mutant).meets(target)
                    {
                        found.push(edits.to_vec());
                    }
                },
            );
            edits.pop();
        }
        (screened, found)
    });

    let mut hits = vec![Vec::new(); k];
    let mut screened = 0;
    for (count, found) in per_top {
        screened += count;
        for edits in found {
            hits[edits.len() - 1].push(edits);
        }
    }
    let hits = hits
        .into_iter()
        .map(|found| {
            par_map(&found, |edits| {
                let mut sorted = edits.clone();
                sorted.sort_unstable();
                (sorted, lattice(start, edits, scorer))
            })
        })
        .collect();
    Search {
        start_units: scorer.paid_units(start),
        start_rungs: scorer.solid(start),
        screened,
        hits,
    }
}

/// Visits the mutant as it stands, then every further substitution at a position below
/// `top`, `left` more at most.
fn below(
    tape: &mut [u8],
    start: &[u8],
    top: usize,
    left: usize,
    edits: &mut Vec<Edit>,
    visit: &mut dyn FnMut(&[u8], &[Edit]),
) {
    visit(tape, edits);
    if left == 0 {
        return;
    }
    for at in 0..top {
        for byte in ALPHABET {
            if byte == start[at] {
                continue;
            }
            tape[at] = byte;
            edits.push((at, byte));
            below(tape, start, at, left - 1, edits, visit);
            edits.pop();
        }
        tape[at] = start[at];
    }
}

impl Distance {
    pub fn render(&self) -> String {
        let mut out = String::new();
        match self.substitutions {
            Some(d) => {
                let _ = writeln!(out, "substitutions {d}");
            }
            None => {
                let _ = writeln!(out, "the tapes differ in length: no substitution distance");
            }
        }
        let _ = writeln!(out, "edit distance {}", self.edits);
        match &self.orders {
            Some(orders) => render_orders(&mut out, orders),
            None if self.substitutions.is_some() => {
                let _ = writeln!(out, "over {LATTICE_MAX} substitutions: no lattice read");
            }
            None => {}
        }
        out
    }
}

fn render_orders(out: &mut String, orders: &Orders) {
    let _ = match &orders.credited {
        Some(units) => writeln!(out, "a credited order: units {units:?}"),
        None => writeln!(out, "no credited order"),
    };
    let _ = match &orders.neutral {
        Some(units) => writeln!(out, "a neutral-or-better order: units {units:?}"),
        None => writeln!(out, "no neutral-or-better order"),
    };
}

impl Search {
    pub fn render(&self, examples: usize) -> String {
        let mut out = String::new();
        let _ = writeln!(
            out,
            "start {} ({} paid units); screened {} mutants",
            self.start_rungs.names(),
            self.start_units,
            self.screened
        );
        for (k, hits) in self.hits.iter().enumerate() {
            let credited = hits.iter().filter(|(_, o)| o.credited.is_some()).count();
            let neutral = hits.iter().filter(|(_, o)| o.neutral.is_some()).count();
            let _ = writeln!(
                out,
                "k={}: {} hits, {credited} with a credited order, {neutral} neutral or better",
                k + 1,
                hits.len()
            );
            for (edits, orders) in hits.iter().take(examples) {
                let spelled: Vec<String> = edits
                    .iter()
                    .map(|(at, byte)| format!("{at}={}", crate::tape::show(&[*byte])))
                    .collect();
                let _ = writeln!(out, "   {}", spelled.join(","));
                let mut lines = String::new();
                render_orders(&mut lines, orders);
                for line in lines.lines() {
                    let _ = writeln!(out, "      {line}");
                }
            }
        }
        let _ = writeln!(
            out,
            "shortest: {}; shortest credited: {}",
            self.shortest()
                .map_or("none within k".into(), |k| k.to_string()),
            self.shortest_credited()
                .map_or("none within k".into(), |k| k.to_string())
        );
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::score::tests::{meta_stack_params, stack_solver};
    use crate::score::DEEP;
    use crate::tape::FILLER;

    fn scorer() -> Scorer {
        Scorer::for_params(&meta_stack_params())
    }

    #[test]
    fn a_tape_is_no_distance_from_itself() {
        let xor = stack_solver(8);
        let d = distance(&xor, &xor, &scorer());
        assert_eq!(d.substitutions, Some(0));
        assert_eq!(d.edits, 0);
        let orders = d.orders.unwrap();
        assert_eq!(orders.credited, Some(vec![8]));
        assert_eq!(orders.neutral, Some(vec![8]));
    }

    /// The stack XOR with its emit blanked earns nothing; writing the emit back is one
    /// credited substitution. Backwards it is a loss, so neither order holds.
    #[test]
    fn one_substitution_from_a_blanked_emit_to_xor_is_credited() {
        let xor = stack_solver(8);
        let mut blank = xor.clone();
        blank[12] = FILLER;
        let up = distance(&blank, &xor, &scorer());
        assert_eq!(up.substitutions, Some(1));
        assert_eq!(up.orders.clone().unwrap().credited, Some(vec![0, 8]));
        let down = distance(&xor, &blank, &scorer());
        assert_eq!(down.orders.unwrap(), Orders::default());
    }

    /// EQU is XOR with one more NAND before the emit: two substitutions (`!` to `~` at 12,
    /// `0` to `!` at 13). Either single breaks XOR's emit or adds a second one after it, so
    /// the lattice reads each order.
    #[test]
    fn xor_to_equ_is_two_substitutions_through_the_lattice() {
        let d = distance(&stack_solver(8), &stack_solver(9), &scorer());
        assert_eq!(d.substitutions, Some(2));
        let orders = d.orders.unwrap();
        let neutral = orders.neutral.unwrap();
        assert_eq!((neutral[0], neutral[2], neutral.len()), (8, 16, 3));
    }

    #[test]
    fn tapes_of_two_lengths_have_only_an_edit_distance() {
        let d = distance(b"<{~!", b"<<{~!", &scorer());
        assert_eq!(d.substitutions, None);
        assert_eq!(d.edits, 1);
        assert_eq!(d.orders, None);
    }

    /// One NAND of the stack XOR blanked: the search finds the one substitution back, and
    /// none from the zero tape.
    #[test]
    fn the_search_finds_a_known_one_substitution_deep_solver() {
        let mut broken = stack_solver(8);
        broken[9] = FILLER;
        let search = search(&broken, &scorer(), 16, 1, DEEP);
        assert_eq!(search.screened, 16 * 13);
        assert_eq!(search.shortest(), Some(1));
        assert!(search.hits[0]
            .iter()
            .any(|(edits, _)| edits == &vec![(9, b'~')]));

        let zeros = vec![0u8; 32];
        let nothing = super::search(&zeros, &scorer(), 8, 2, DEEP);
        assert_eq!(nothing.screened, 8 * 13 + 28 * 13 * 13);
        assert_eq!(nothing.shortest(), None);
        assert_eq!(nothing.shortest_credited(), None);
    }

    /// Two NANDs blanked: no single substitution gets back, the pair does, and the search
    /// reads it as k = 2.
    #[test]
    fn the_search_counts_a_two_substitution_crossing_as_two() {
        let mut broken = stack_solver(8);
        broken[9] = FILLER;
        broken[11] = FILLER;
        let search = search(&broken, &scorer(), 13, 2, DEEP);
        assert_eq!(search.hits[0].len(), 0);
        assert!(search.hits[1]
            .iter()
            .any(|(edits, _)| edits == &vec![(9, b'~'), (11, b'~')]));
        assert_eq!(search.shortest(), Some(2));
    }
}
