//! Reading (a) on the topless ladder: per depth, the cells whose assayed tape is credited a
//! rung that deep on all six fixed sets and the commonest such tape; the rungs held by a
//! tenth of the world; and the topless-rise entry's (2026-10-02, H-rise-code) deepest solid
//! rung and dominant deepest solver.

use crate::census::{cells, ranked};
use crate::depth::{depth_name, rung_name, DepthScorer, Solid};
use crate::score::{assayed, par_map};
use crate::tape::{hex, show};
use life_engine::topless::{Inputs, DEPTH_FLOOR};
use life_engine::World;
use std::collections::BTreeMap;
use std::fmt::Write;

/// One depth's tally.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DepthRow {
    pub depth: u32,
    /// Cells credited, on all six sets, some rung exactly this deep.
    pub cells: u64,
    /// The commonest assayed tape so credited, ties to the smaller tape, and its cells.
    pub commonest: (Vec<u8>, u64),
}

/// The deepest rung held by a tenth of the world and its commonest solver.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Deepest {
    pub depth: u32,
    /// The held rungs at that depth, each with its cells.
    pub rungs: Vec<(u16, u64)>,
    /// The dominant deepest solver: the commonest assayed tape credited one of `rungs` on
    /// all six sets, ties broken by byte order.
    pub solver: Vec<u8>,
    pub solver_cells: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DepthCensus {
    pub epoch: u64,
    pub cells: u64,
    pub inputs: Inputs,
    pub carries_meta: bool,
    pub distinct_assayed: usize,
    pub depths: Vec<DepthRow>,
    /// Every rung credited a tenth of the cells or more on all six sets, deepest first.
    pub held: Vec<(u16, u64)>,
    pub deepest: Option<Deepest>,
}

/// Whether `credited` cells are a tenth of `cells` or more: 1 639 of 16 384.
fn a_tenth(credited: u64, cells: u64) -> bool {
    credited * 10 >= cells
}

pub fn census(world: &World, scorer: &DepthScorer) -> DepthCensus {
    let params = world.params();
    let cell_count = params.cell_count() as u64;
    let ranked = ranked(cells(world).map(|(x, y)| assayed(world, x, y)));
    let solids: Vec<Solid> = par_map(&ranked, |(tape, _)| scorer.solid(tape));
    let inputs = scorer.inputs();

    let mut by_class: BTreeMap<u16, u64> = BTreeMap::new();
    let mut depths: BTreeMap<u32, DepthRow> = BTreeMap::new();
    for ((tape, count), solid) in ranked.iter().zip(&solids) {
        for class in &solid.classes {
            *by_class.entry(*class).or_default() += count;
        }
        let mut seen: Vec<u32> = solid
            .classes
            .iter()
            .map(|class| inputs.depth(*class))
            .collect();
        seen.sort_unstable();
        seen.dedup();
        for depth in seen {
            depths
                .entry(depth)
                .and_modify(|row| row.cells += count)
                .or_insert_with(|| DepthRow {
                    depth,
                    cells: *count,
                    commonest: (tape.to_vec(), *count),
                });
        }
    }

    let mut held: Vec<(u16, u64)> = by_class
        .into_iter()
        .filter(|(_, credited)| a_tenth(*credited, cell_count))
        .collect();
    held.sort_by(|a, b| {
        inputs
            .depth(b.0)
            .cmp(&inputs.depth(a.0))
            .then(b.1.cmp(&a.1))
            .then(a.0.cmp(&b.0))
    });
    let deepest = held
        .first()
        .map(|(class, _)| inputs.depth(*class))
        .map(|depth| {
            let rungs: Vec<(u16, u64)> = held
                .iter()
                .filter(|(class, _)| inputs.depth(*class) == depth)
                .copied()
                .collect();
            let ((solver, solver_cells), _) = ranked
                .iter()
                .zip(&solids)
                .find(|(_, solid)| rungs.iter().any(|(class, _)| solid.has(*class)))
                .expect("a held rung is credited to some tape");
            Deepest {
                depth,
                rungs,
                solver: solver.to_vec(),
                solver_cells: *solver_cells,
            }
        });

    DepthCensus {
        epoch: world.epoch(),
        cells: cell_count,
        inputs,
        carries_meta: params.carries_meta(),
        distinct_assayed: ranked.len(),
        depths: depths.into_values().rev().collect(),
        held,
        deepest,
    }
}

impl DepthCensus {
    pub fn render(&self) -> String {
        let mut out = String::new();
        let assayed = if self.carries_meta {
            "metabolism"
        } else {
            "replicating (assayed)"
        };
        let ladder = match self.inputs {
            Inputs::Three => "logic3",
            Inputs::Four => "logic4",
        };
        let _ = writeln!(
            out,
            "epoch {} cells {} ladder {ladder} distinct {assayed} tapes {}",
            self.epoch, self.cells, self.distinct_assayed
        );
        let _ = writeln!(
            out,
            "\nper depth, {assayed} tapes credited a rung that deep on all 6 fixed sets:"
        );
        for row in &self.depths {
            let tenth = if a_tenth(row.cells, self.cells) {
                " (a tenth)"
            } else {
                ""
            };
            let floor = if row.depth >= DEPTH_FLOOR {
                " (or more)"
            } else {
                ""
            };
            let _ = writeln!(
                out,
                "  {:2}{floor} {:6} cells{tenth}; commonest n={} {}  {}",
                row.depth,
                row.cells,
                row.commonest.1,
                show(&row.commonest.0),
                hex(&row.commonest.0)
            );
        }
        let held: Vec<String> = self
            .held
            .iter()
            .map(|(class, cells)| format!("{} n={cells}", rung_name(self.inputs, *class)))
            .collect();
        let _ = writeln!(
            out,
            "\nrungs held by a tenth: {}",
            if held.is_empty() {
                "none".into()
            } else {
                held.join(", ")
            }
        );
        let _ = match &self.deepest {
            Some(deepest) => writeln!(
                out,
                "\ndeepest solid rung: depth {}\ndominant deepest solver: n={} {}  {}",
                depth_name(deepest.depth),
                deepest.solver_cells,
                show(&deepest.solver),
                hex(&deepest.solver)
            ),
            None => writeln!(out, "\nno rung held by a tenth: no deepest solver"),
        };
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::score::tests::{meta_stack_params, stack_solver};
    use life_engine::params::Tasks;

    fn logic4_params() -> life_engine::Params {
        life_engine::Params {
            tasks: Tasks::Logic4,
            ..meta_stack_params()
        }
    }

    /// The stack XOR (depth 4) in eight cells, an eighth of the 8×8 world, so held, as two
    /// tapes differing in a padding byte, tied at four cells each and broken by byte order;
    /// the stack EQU (depth 5) in four cells, not held.
    fn planted() -> World {
        let params = logic4_params();
        let mut world = World::new(&params, 3).unwrap();
        let zeros = vec![0u8; 32];
        for (x, y) in cells(&world).collect::<Vec<_>>() {
            world.set_metabolism(x, y, &zeros);
        }
        let mut other = stack_solver(8);
        other[31] = crate::tape::FILLER;
        for x in 0..4 {
            world.set_metabolism(x, 0, &other);
            world.set_metabolism(x, 1, &stack_solver(8));
            world.set_metabolism(x, 2, &stack_solver(9));
        }
        world
    }

    #[test]
    fn the_census_reads_the_deepest_rung_held_and_its_dominant_solver() {
        let world = planted();
        let scorer = DepthScorer::for_params(&logic4_params()).unwrap();
        let census = census(&world, &scorer);
        assert_eq!(census.inputs, Inputs::Four);
        assert_eq!(census.distinct_assayed, 4);
        let depths: Vec<(u32, u64)> = census.depths.iter().map(|r| (r.depth, r.cells)).collect();
        assert_eq!(depths, [(5, 4), (4, 8)]);
        let deepest = census.deepest.as_ref().unwrap();
        assert_eq!(deepest.depth, 4);
        assert_eq!(deepest.rungs, [(0x0ff0, 8)]);
        assert_eq!(
            (deepest.solver.clone(), deepest.solver_cells),
            (stack_solver(8), 4)
        );
        assert!(census.render().contains("deepest solid rung: depth 4"));
    }

    #[test]
    fn the_census_is_deterministic_and_reads_nothing_held_on_a_blank_world() {
        let world = planted();
        let scorer = DepthScorer::for_params(&logic4_params()).unwrap();
        assert_eq!(census(&world, &scorer), census(&world, &scorer));

        let mut blank = World::new(&logic4_params(), 3).unwrap();
        for (x, y) in cells(&blank).collect::<Vec<_>>() {
            blank.set_metabolism(x, y, &[0u8; 32]);
        }
        let census = census(&blank, &scorer);
        assert!(census.held.is_empty());
        assert_eq!(census.deepest, None);
        assert!(census.render().contains("no deepest solver"));
    }
}
