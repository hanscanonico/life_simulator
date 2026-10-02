//! Reading (c): heritability by planting, with its unplanted control, exactly as the
//! Meta-stack entry (2026-10-02) locks it.
//!
//! The deep solver (its cell's replicating and metabolism tapes) is planted as a `side`×
//! `side` block in the centre of the child's own end world, and every other cell whose
//! assayed tape is credited the rung is given the world's commonest assayed tape without
//! it. The control is the same world with the block given that commonest tape too, and the
//! block's replicating tapes left as planted, so the two worlds differ only in the block's
//! metabolism tapes. Both run under the child's params for `epochs` on each seed.
//!
//! **Heritable** where, in at least 2 of the 3 seeds, the planted world holds a tenth of
//! the world credited the rung on all six sets while its control, same seed, holds 16
//! cells or fewer. Where a control also reaches the tenth the rung re-arose from the
//! reseeded tape, and the reading is **unresolved**.

use crate::census::{cells, ranked};
use crate::score::{assayed, par_map, Rungs, Scorer};
use crate::stored::Stored;
use crate::tape::{hex, show};
use life_engine::logic::LOGIC_TASKS;
use life_engine::World;
use std::collections::HashMap;
use std::fmt::Write;

pub const SEEDS: [u64; 3] = [2001, 2002, 2003];
pub const EPOCHS: u64 = 2_000;
pub const SIDE: u32 = 4;
/// The most cells the control may hold credited the rung for a seed to count.
pub const CONTROL_MOST: u64 = 16;
/// Seeds of the three that must count.
pub const SEEDS_NEEDED: usize = 2;

pub struct Plan {
    pub rung: usize,
    /// The tape the assay reads: the metabolism tape, or on a run without one the
    /// replicating tape.
    pub deep: Vec<u8>,
    /// The planted cells' replicating tape, on a run with a metabolism tape.
    pub replicating: Option<Vec<u8>>,
    pub side: u32,
    pub seeds: Vec<u64>,
    pub epochs: u64,
    pub every: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SeedRun {
    pub seed: u64,
    /// Per reading, the epoch past the plant and the cells credited the rung.
    pub planted: Vec<(u64, u64)>,
    pub control: Vec<(u64, u64)>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Verdict {
    Heritable,
    Unresolved,
    NotHeritable,
}

pub struct Planting {
    pub filler: Vec<u8>,
    pub wiped: u64,
    pub cells: u64,
    pub runs: Vec<SeedRun>,
}

/// The cell whose assayed tape is `deep`, first in row order, and its replicating tape.
pub fn replicating_of(world: &World, deep: &[u8]) -> Option<Vec<u8>> {
    cells(world)
        .find(|(x, y)| assayed(world, *x, *y) == deep)
        .map(|(x, y)| world.cell(x, y).to_vec())
}

pub fn plant(stored: &Stored, scorer: &Scorer, plan: &Plan) -> Result<Planting, String> {
    let params = &stored.params;
    if params.carries_meta() != plan.replicating.is_some() {
        return Err(
            "a run with a metabolism tape plants a replicating tape beside it; one without plants \
             the assayed tape alone"
                .into(),
        );
    }
    let fits = |tape: &[u8], meta: bool| match (meta, params.grows()) {
        (true, _) => tape.len() == params.meta_len as usize,
        (false, true) => (1..=params.stride()).contains(&tape.len()),
        (false, false) => tape.len() == params.stride(),
    };
    let replicating_fits = plan.replicating.as_deref().is_none_or(|t| fits(t, false));
    if !fits(&plan.deep, params.carries_meta()) || !replicating_fits {
        return Err("a planted tape does not fit the run's cells".into());
    }
    let world = stored.world(0)?;
    if plan.side > world.width() || plan.side > world.height() {
        return Err(format!("a {0}×{0} block does not fit the world", plan.side));
    }
    let rung = Rungs::one(plan.rung);
    let ranked = ranked(cells(&world).map(|(x, y)| assayed(&world, x, y)));
    let carrying = par_map(&ranked, |(tape, _)| scorer.any(tape).meets(rung));
    let filler = ranked
        .iter()
        .zip(&carrying)
        .find(|(_, carries)| !**carries)
        .map(|((tape, _), _)| tape.to_vec())
        .ok_or("every cell is credited the rung on some set: there is nothing to wipe it with")?;
    let carriers: HashMap<&[u8], bool> = ranked
        .iter()
        .zip(&carrying)
        .map(|((tape, _), carries)| (*tape, *carries))
        .collect();
    let wiped_cells: Vec<(u32, u32)> = cells(&world)
        .filter(|(x, y)| carriers[assayed(&world, *x, *y)])
        .collect();

    let arms: Vec<(u64, bool)> = plan
        .seeds
        .iter()
        .flat_map(|seed| [(*seed, true), (*seed, false)])
        .collect();
    let readings = par_map(
        &arms,
        |(seed, planted)| -> Result<Vec<(u64, u64)>, String> {
            let mut world = stored.world(*seed)?;
            prepare(&mut world, plan, &filler, &wiped_cells, *planted);
            Ok(run(&mut world, scorer, plan))
        },
    );
    let mut readings = readings.into_iter();
    let mut runs = Vec::new();
    for seed in &plan.seeds {
        let planted = readings.next().expect("one planted arm a seed")?;
        let control = readings.next().expect("one control arm a seed")?;
        runs.push(SeedRun {
            seed: *seed,
            planted,
            control,
        });
    }
    Ok(Planting {
        filler,
        wiped: wiped_cells.len() as u64,
        cells: params.cell_count() as u64,
        runs,
    })
}

/// The world as the plan starts it: every carrier outside the block wiped, and the block
/// planted, or in the control given the filler.
fn prepare(world: &mut World, plan: &Plan, filler: &[u8], wiped: &[(u32, u32)], planted: bool) {
    let x0 = world.width() / 2 - plan.side / 2;
    let y0 = world.height() / 2 - plan.side / 2;
    let in_block =
        |x: u32, y: u32| (x0..x0 + plan.side).contains(&x) && (y0..y0 + plan.side).contains(&y);
    let block_tape = if planted { &plan.deep[..] } else { filler };
    let set_assayed = |world: &mut World, x, y, tape: &[u8]| match plan.replicating {
        Some(_) => world.set_metabolism(x, y, tape),
        None => world.set_cell(x, y, tape),
    };
    for (x, y) in wiped {
        if !in_block(*x, *y) {
            set_assayed(world, *x, *y, filler);
        }
    }
    for y in y0..y0 + plan.side {
        for x in x0..x0 + plan.side {
            if let Some(replicating) = &plan.replicating {
                world.set_cell(x, y, replicating);
            }
            set_assayed(world, x, y, block_tape);
        }
    }
}

fn run(world: &mut World, scorer: &Scorer, plan: &Plan) -> Vec<(u64, u64)> {
    let mut readings = Vec::new();
    for epoch in 0..=plan.epochs {
        if epoch % plan.every == 0 || epoch == plan.epochs {
            readings.push((epoch, credited(world, scorer, plan.rung)));
        }
        if epoch < plan.epochs {
            world.step();
        }
    }
    readings
}

/// The cells whose assayed tape is credited `rung` on all six sets.
pub fn credited(world: &World, scorer: &Scorer, rung: usize) -> u64 {
    let rung = Rungs::one(rung);
    let mut seen: HashMap<&[u8], bool> = HashMap::new();
    cells(world)
        .filter(|(x, y)| {
            let tape = assayed(world, *x, *y);
            *seen.entry(tape).or_insert_with(|| {
                scorer.on_set(tape, 0).meets(rung) && scorer.solid(tape).meets(rung)
            })
        })
        .count() as u64
}

impl SeedRun {
    fn last(readings: &[(u64, u64)]) -> u64 {
        readings.last().map_or(0, |(_, cells)| *cells)
    }

    pub fn planted_cells(&self) -> u64 {
        Self::last(&self.planted)
    }

    pub fn control_cells(&self) -> u64 {
        Self::last(&self.control)
    }
}

fn tenth(cells: u64, world: u64) -> bool {
    cells * 10 >= world
}

pub fn verdict(runs: &[SeedRun], world_cells: u64) -> Verdict {
    let counted = runs
        .iter()
        .filter(|run| {
            tenth(run.planted_cells(), world_cells) && run.control_cells() <= CONTROL_MOST
        })
        .count();
    if counted >= SEEDS_NEEDED {
        Verdict::Heritable
    } else if runs
        .iter()
        .any(|run| tenth(run.control_cells(), world_cells))
    {
        Verdict::Unresolved
    } else {
        Verdict::NotHeritable
    }
}

impl Planting {
    pub fn render(&self, plan: &Plan) -> String {
        let mut out = String::new();
        let name = LOGIC_TASKS[plan.rung].name;
        let _ = writeln!(
            out,
            "plant {name}: {} {}\n  a {}×{} block; {} other cells credited {name} on some set wiped with \
             the commonest tape without it, {} {}",
            show(&plan.deep),
            hex(&plan.deep),
            plan.side,
            plan.side,
            self.wiped,
            show(&self.filler),
            hex(&self.filler),
        );
        if let Some(replicating) = &plan.replicating {
            let _ = writeln!(out, "  replicating tape {}", hex(replicating));
        }
        for run in &self.runs {
            let _ = writeln!(out, "seed {}:", run.seed);
            for ((epoch, planted), (_, control)) in run.planted.iter().zip(&run.control) {
                let _ = writeln!(
                    out,
                    "  e+{epoch:<6} planted {planted:6}  control {control:6}"
                );
            }
        }
        let tenth = self.cells.div_ceil(10);
        let _ = writeln!(
            out,
            "verdict: {:?} (a tenth is {tenth} cells; a control counts at {CONTROL_MOST} or fewer)",
            verdict(&self.runs, self.cells)
        );
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::score::tests::{meta_stack_params, stack_solver};

    fn seed_run(planted: u64, control: u64) -> SeedRun {
        SeedRun {
            seed: 0,
            planted: vec![(0, 16), (2000, planted)],
            control: vec![(0, 0), (2000, control)],
        }
    }

    #[test]
    fn the_verdict_is_the_entrys_rule() {
        let world = 16_384;
        let held = seed_run(1639, 16);
        let lost = seed_run(1638, 0);
        let rearose = seed_run(5000, 1639);
        let leaky = seed_run(5000, 17);
        assert_eq!(
            verdict(&[held.clone(), held.clone(), lost.clone()], world),
            Verdict::Heritable
        );
        assert_eq!(
            verdict(&[held.clone(), held.clone(), rearose.clone()], world),
            Verdict::Heritable
        );
        assert_eq!(
            verdict(&[held.clone(), lost.clone(), lost.clone()], world),
            Verdict::NotHeritable
        );
        assert_eq!(
            verdict(&[held.clone(), leaky.clone(), lost], world),
            Verdict::NotHeritable
        );
        assert_eq!(
            verdict(&[held, rearose.clone(), rearose], world),
            Verdict::Unresolved
        );
    }

    /// An 8×8 Meta-stack world stored past its start, with a stack XOR in two corner cells.
    fn stored_world() -> Stored {
        let params = meta_stack_params();
        let mut world = World::new(&params, 9).unwrap();
        for _ in 0..16 {
            world.step();
        }
        world.set_metabolism(0, 0, &stack_solver(8));
        world.set_metabolism(7, 7, &stack_solver(8));
        Stored {
            blob: world.snapshot(),
            params,
        }
    }

    fn plan(stored: &Stored) -> Plan {
        let world = stored.world(0).unwrap();
        Plan {
            rung: 8,
            deep: stack_solver(8),
            replicating: replicating_of(&world, &stack_solver(8)),
            side: 2,
            seeds: vec![2001, 2002],
            epochs: 40,
            every: 20,
        }
    }

    #[test]
    fn the_planted_and_control_worlds_differ_only_in_the_blocks_metabolism_tapes() {
        let stored = stored_world();
        let plan = plan(&stored);
        let scorer = Scorer::for_params(&stored.params);
        let wiped = vec![(0, 0), (7, 7)];
        let commonest = vec![0u8; 32];
        let mut planted = stored.world(1).unwrap();
        prepare(&mut planted, &plan, &commonest, &wiped, true);
        let mut control = stored.world(1).unwrap();
        prepare(&mut control, &plan, &commonest, &wiped, false);

        assert_eq!(credited(&planted, &scorer, 8), 4);
        assert_eq!(credited(&control, &scorer, 8), 0);
        for (x, y) in cells(&planted).collect::<Vec<_>>() {
            assert_eq!(planted.cell(x, y), control.cell(x, y));
            let in_block = (3..5).contains(&x) && (3..5).contains(&y);
            assert_eq!(
                planted.metabolism(x, y) == control.metabolism(x, y),
                !in_block
            );
        }
        assert_eq!(planted.cell(3, 3), &plan.replicating.clone().unwrap()[..]);
    }

    #[test]
    fn a_planting_is_deterministic() {
        let stored = stored_world();
        let plan = plan(&stored);
        let scorer = Scorer::for_params(&stored.params);
        let first = plant(&stored, &scorer, &plan).unwrap();
        let again = plant(&stored, &scorer, &plan).unwrap();
        assert_eq!(first.runs, again.runs);
        assert_eq!(first.wiped, 2);
        assert_eq!(first.runs.len(), 2);
        assert_eq!(first.runs[0].planted[0], (0, 4));
        assert_eq!(first.runs[0].control[0], (0, 0));
        assert_eq!(first.runs[0].planted.len(), 3);
        assert!(first.render(&plan).contains("verdict: "));
    }

    #[test]
    fn a_tape_that_does_not_fit_is_refused() {
        let stored = stored_world();
        let scorer = Scorer::for_params(&stored.params);
        let short = Plan {
            deep: stack_solver(8)[..31].to_vec(),
            ..plan(&stored)
        };
        assert!(plant(&stored, &scorer, &short).is_err());
        let woven = Plan {
            replicating: None,
            ..plan(&stored)
        };
        assert!(plant(&stored, &scorer, &woven).is_err());
    }
}
