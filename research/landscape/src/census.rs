//! Reading (a): the commonest assayed and replicating tapes of a stored world, each with its
//! logic credit under the run's own NAND, and per rung the cells credited it on all six sets
//! and the commonest tape so credited. On a run with a metabolism tape the assay reads that
//! tape; the replicating tape's credit is the one the run never pays.

use crate::score::{assayed, par_map, Rungs, Scorer, DEEP};
use crate::tape::{hex, show};
use life_engine::logic::LOGIC_TASKS;
use life_engine::{replicator, rng, World};
use std::collections::HashMap;
use std::fmt::Write;

/// The stream the detector's noise is drawn on, the design study's.
const DETECTOR_STREAM: u64 = 0xdead;

pub struct Row {
    pub tape: Vec<u8>,
    pub cells: u64,
    pub solid: Rungs,
    /// Whether the orientation-aware detector passes the tape: aligned, rotated.
    pub copies: Option<(bool, bool)>,
}

pub struct Census {
    pub epoch: u64,
    pub cells: u64,
    pub carries_meta: bool,
    pub distinct_assayed: usize,
    pub assayed: Vec<Row>,
    pub replicating: Vec<Row>,
    /// Per rung, the cells whose assayed tape is credited it on all six sets.
    pub credited_cells: [u64; 10],
    /// Per rung, the commonest assayed tape credited it on all six sets, ties to the
    /// smaller tape, and its cells.
    pub commonest: [Option<(Vec<u8>, u64)>; 10],
    /// The commonest assayed tape credited XOR or EQU on all six sets: the Meta-stack
    /// entry's "first deep solver" when read on the first stored world past the deep rung's
    /// first epoch.
    pub deep_solver: Option<(Vec<u8>, u64)>,
}

/// Distinct tapes by cells, most first, ties in ascending byte order.
pub fn ranked<'a>(tapes: impl Iterator<Item = &'a [u8]>) -> Vec<(&'a [u8], u64)> {
    let mut counts: HashMap<&[u8], u64> = HashMap::new();
    for tape in tapes {
        *counts.entry(tape).or_default() += 1;
    }
    let mut ranked: Vec<_> = counts.into_iter().collect();
    ranked.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(b.0)));
    ranked
}

pub fn cells(world: &World) -> impl Iterator<Item = (u32, u32)> + '_ {
    (0..world.height()).flat_map(move |y| (0..world.width()).map(move |x| (x, y)))
}

pub fn census(world: &World, scorer: &Scorer, top: usize) -> Census {
    let params = world.params();
    let carries_meta = params.carries_meta();
    let assayed_ranked = ranked(cells(world).map(|(x, y)| assayed(world, x, y)));
    let solids = par_map(&assayed_ranked, |(tape, _)| {
        if scorer.on_set(tape, 0).0 == 0 {
            Rungs(0)
        } else {
            scorer.solid(tape)
        }
    });

    let mut credited_cells = [0u64; 10];
    let mut commonest: [Option<(Vec<u8>, u64)>; 10] = Default::default();
    let mut deep_solver = None;
    for ((tape, count), solid) in assayed_ranked.iter().zip(&solids) {
        if solid.meets(DEEP) && deep_solver.is_none() {
            deep_solver = Some((tape.to_vec(), *count));
        }
        for rung in 0..LOGIC_TASKS.len() {
            if solid.has(rung) {
                credited_cells[rung] += count;
                commonest[rung].get_or_insert_with(|| (tape.to_vec(), *count));
            }
        }
    }

    let copies = |tape: &[u8]| {
        let mut noise = rng::seeded(DETECTOR_STREAM, 1, 0);
        let verdict = replicator::self_replicates(tape, params.max_steps, scorer.ops(), &mut noise);
        (verdict.aligned, verdict.rotated)
    };
    let assayed_rows = assayed_ranked
        .iter()
        .zip(&solids)
        .take(top)
        .map(|((tape, count), solid)| Row {
            tape: tape.to_vec(),
            cells: *count,
            solid: *solid,
            copies: (!carries_meta).then(|| copies(tape)),
        })
        .collect();
    let replicating = if carries_meta {
        let ranked = ranked(cells(world).map(|(x, y)| world.cell(x, y)));
        par_map(&ranked[..top.min(ranked.len())], |(tape, count)| Row {
            tape: tape.to_vec(),
            cells: *count,
            solid: scorer.solid(tape),
            copies: Some(copies(tape)),
        })
    } else {
        Vec::new()
    };

    Census {
        epoch: world.epoch(),
        cells: params.cell_count() as u64,
        carries_meta,
        distinct_assayed: assayed_ranked.len(),
        assayed: assayed_rows,
        replicating,
        credited_cells,
        commonest,
        deep_solver,
    }
}

impl Census {
    pub fn render(&self) -> String {
        let mut out = String::new();
        let assayed = if self.carries_meta {
            "metabolism"
        } else {
            "replicating (assayed)"
        };
        let _ = writeln!(
            out,
            "epoch {} cells {} distinct {assayed} tapes {}",
            self.epoch, self.cells, self.distinct_assayed
        );
        let _ = writeln!(
            out,
            "\ncommonest {assayed} tapes (credit on all 6 fixed sets):"
        );
        render_rows(&mut out, &self.assayed);
        if self.carries_meta {
            let _ = writeln!(
                out,
                "\ncommonest replicating tapes (credit under the run's NAND, never paid):"
            );
            render_rows(&mut out, &self.replicating);
        }
        let _ = writeln!(out, "\nper rung, {assayed} tapes credited on all 6 sets:");
        for (rung, task) in LOGIC_TASKS.iter().enumerate() {
            let cells = self.credited_cells[rung];
            let tenth = if cells * 10 >= self.cells {
                " (a tenth)"
            } else {
                ""
            };
            match &self.commonest[rung] {
                Some((tape, count)) => {
                    let _ = writeln!(
                        out,
                        "  {:5} {cells:6} cells{tenth}; commonest n={count} {}  {}",
                        task.name,
                        show(tape),
                        hex(tape)
                    );
                }
                None => {
                    let _ = writeln!(out, "  {:5} {cells:6} cells", task.name);
                }
            }
        }
        let _ = match &self.deep_solver {
            Some((tape, count)) => writeln!(
                out,
                "\ncommonest deep solver (xor or equ on all 6 sets): n={count} {}  {}",
                show(tape),
                hex(tape)
            ),
            None => writeln!(out, "\nno deep solver (xor or equ on all 6 sets)"),
        };
        out
    }
}

fn render_rows(out: &mut String, rows: &[Row]) {
    for row in rows {
        let copies = match row.copies {
            Some((aligned, rotated)) => format!(" copies aligned={aligned} rotated={rotated}"),
            None => String::new(),
        };
        let _ = writeln!(
            out,
            "  n={:<6} {:<14}{copies}\n           {}\n           {}",
            row.cells,
            row.solid.names(),
            show(&row.tape),
            hex(&row.tape)
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::score::tests::{meta_stack_params, stack_solver};
    use life_engine::Params;

    #[test]
    fn ranking_counts_cells_and_breaks_ties_by_bytes() {
        let tapes: [&[u8]; 5] = [b"b", b"a", b"c", b"b", b"a"];
        let ranked = ranked(tapes.into_iter());
        assert_eq!(ranked, vec![(&b"a"[..], 2), (&b"b"[..], 2), (&b"c"[..], 1)]);
    }

    /// Three metabolism tapes planted: XOR in four cells, NOR in two, and the tally reads
    /// them on all six sets with the commonest of each rung.
    #[test]
    fn the_census_reads_the_metabolism_tapes_under_the_runs_nand() {
        let params = meta_stack_params();
        let mut world = World::new(&params, 3).unwrap();
        let zeros = vec![0u8; 32];
        for (x, y) in cells(&world).collect::<Vec<_>>() {
            world.set_metabolism(x, y, &zeros);
        }
        for x in 0..4 {
            world.set_metabolism(x, 0, &stack_solver(8));
        }
        for x in 0..2 {
            world.set_metabolism(x, 1, &stack_solver(7));
        }
        let census = census(&world, &Scorer::for_params(&params), 3);
        assert_eq!(census.distinct_assayed, 3);
        assert_eq!(census.assayed[0].tape, zeros);
        assert_eq!(census.assayed[0].cells, 58);
        assert_eq!(census.assayed[1].solid, Rungs::one(8));
        assert_eq!(census.credited_cells[8], 4);
        assert_eq!(census.credited_cells[7], 2);
        assert_eq!(census.credited_cells[9], 0);
        assert_eq!(census.commonest[8], Some((stack_solver(8), 4)));
        assert_eq!(census.deep_solver, Some((stack_solver(8), 4)));
        assert_eq!(census.replicating.len(), 3);
        assert!(census.render().contains("commonest n=4 <<{~~{{>>~{~!"));

        let in_place = Params {
            logic_nand: life_engine::params::LogicNand::InPlace,
            ..params
        };
        let census = super::census(&world, &Scorer::for_params(&in_place), 3);
        assert_eq!(census.credited_cells[8], 0);
        assert_eq!(census.deep_solver, None);
    }
}
