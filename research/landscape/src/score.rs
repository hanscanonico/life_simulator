//! The logic assay as the readings apply it: a run's own instruction set, NAND and floor,
//! on six fixed case sets.

use life_engine::logic::{self, Cases, LOGIC_TASKS};
use life_engine::params::LogicNand;
use life_engine::{OpSet, Params, World};

/// "The 6 fixed case sets" of the Meta-stack entry (2026-10-02): the six separating draws the
/// design study's landscape searches scored on, `logic::Cases::draw` six times off
/// `rng::seeded(0xdee9, 1, 0)`, frozen here so no later engine change can move them.
pub const FIXED_CASE_SETS: [[(u8, u8); 3]; 6] = [
    [(0xd0, 0x80), (0x58, 0x41), (0xe2, 0x9e)],
    [(0x63, 0xd0), (0xc3, 0x41), (0x1b, 0xf2)],
    [(0xc6, 0xc7), (0x4a, 0x72), (0x4c, 0xb5)],
    [(0xba, 0xec), (0xbe, 0x87), (0x51, 0x50)],
    [(0x6b, 0x2d), (0x9c, 0x51), (0xae, 0x56)],
    [(0x57, 0x42), (0xa5, 0x54), (0x6d, 0xf3)],
];

/// The case the study traced every solver on.
pub const TRACE_CASE: (u8, u8) = (0x5a, 0x33);

/// XOR and EQU, the deep rungs, as a mask.
pub const DEEP: Rungs = Rungs((1 << 8) | (1 << 9));

/// A set of logic rungs, a bit per entry of `logic::LOGIC_TASKS`.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub struct Rungs(pub u16);

impl Rungs {
    pub fn one(rung: usize) -> Self {
        Self(1 << rung)
    }

    pub fn has(self, rung: usize) -> bool {
        self.0 & (1 << rung) != 0
    }

    pub fn meets(self, other: Rungs) -> bool {
        self.0 & other.0 != 0
    }

    /// The units the rungs at index `floor` and above are worth: what a run whose
    /// `task_floor` is that rung pays for them.
    pub fn units_from(self, floor: usize) -> u32 {
        (floor..LOGIC_TASKS.len())
            .filter(|rung| self.has(*rung))
            .map(|rung| LOGIC_TASKS[rung].units)
            .sum()
    }

    pub fn names(self) -> String {
        let names: Vec<&str> = (0..LOGIC_TASKS.len())
            .filter(|rung| self.has(*rung))
            .map(|rung| LOGIC_TASKS[rung].name)
            .collect();
        if names.is_empty() {
            "-".into()
        } else {
            names.join("+")
        }
    }

    /// A comma-separated list of rung names, as `--rungs xor,equ` gives it.
    pub fn parse(list: &str) -> Result<Self, String> {
        list.split(',')
            .map(rung_index)
            .try_fold(Self(0), |rungs, rung| Ok(Self(rungs.0 | 1 << rung?)))
    }
}

pub fn rung_index(name: &str) -> Result<usize, String> {
    LOGIC_TASKS
        .iter()
        .position(|task| task.name == name)
        .ok_or_else(|| format!("{name:?} is no logic rung"))
}

/// The assay of one run: its instruction set, its NAND and the lowest rung it pays.
#[derive(Debug, Clone)]
pub struct Scorer {
    sets: Vec<Cases>,
    ops: OpSet,
    nand: LogicNand,
    floor: usize,
}

impl Scorer {
    pub fn for_params(params: &Params) -> Self {
        Self {
            sets: FIXED_CASE_SETS.iter().map(|set| Cases::new(*set)).collect(),
            ops: params.op_set(),
            nand: params.logic_nand,
            floor: params.task_floor_rung(),
        }
    }

    pub fn ops(&self) -> OpSet {
        self.ops
    }

    pub fn nand(&self) -> LogicNand {
        self.nand
    }

    pub fn sets(&self) -> &[Cases] {
        &self.sets
    }

    pub fn on_set(&self, tape: &[u8], set: usize) -> Rungs {
        Rungs(logic::assay_on(tape, &self.sets[set], self.ops, self.nand).bits())
    }

    /// The rungs credited on all six sets: what the readings call a tape's credit.
    pub fn solid(&self, tape: &[u8]) -> Rungs {
        let mut rungs = u16::MAX;
        for set in 0..self.sets.len() {
            rungs &= self.on_set(tape, set).0;
            if rungs == 0 {
                break;
            }
        }
        Rungs(rungs)
    }

    /// The rungs credited on at least one of the six sets.
    pub fn any(&self, tape: &[u8]) -> Rungs {
        Rungs((0..self.sets.len()).fold(0, |rungs, set| rungs | self.on_set(tape, set).0))
    }

    /// The units the run pays for a tape's credit on all six sets.
    pub fn paid_units(&self, tape: &[u8]) -> u32 {
        self.solid(tape).units_from(self.floor)
    }
}

/// The tape the logic assay reads for one cell: its metabolism tape where the run carries
/// them, its replicating tape where it does not.
pub fn assayed(world: &World, x: u32, y: u32) -> &[u8] {
    world.metabolism(x, y).unwrap_or_else(|| world.cell(x, y))
}

/// The length of the tape the assay reads on a run.
pub fn assayed_len(params: &Params) -> usize {
    if params.carries_meta() {
        params.meta_len as usize
    } else {
        params.tape_len as usize
    }
}

/// `f` over `items` on every core, in order.
pub fn par_map<T: Sync, R: Send>(items: &[T], f: impl Fn(&T) -> R + Sync) -> Vec<R> {
    let threads = std::thread::available_parallelism().map_or(1, |n| n.get());
    let chunk = items.len().div_ceil(threads).max(1);
    std::thread::scope(|scope| {
        let handles: Vec<_> = items
            .chunks(chunk)
            .map(|part| scope.spawn(|| part.iter().map(&f).collect::<Vec<R>>()))
            .collect();
        handles
            .into_iter()
            .flat_map(|handle| handle.join().expect("a scoring thread panicked"))
            .collect()
    })
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use crate::tape;
    use life_engine::params::{EnergyPayer, Tasks};

    /// The design study's stack solvers (the engine's `logic::tests::STACK_SOLVERS`), one a
    /// rung from ECHO to EQU.
    pub const STACK_SOLVERS: [&str; 10] = [
        "<!",
        "<{~!",
        "<<{~!",
        "{{<~~!",
        "<<{~~!",
        "{,~<~~!",
        "{,~{~~!",
        "{,~{~>~~!",
        "<<{~~{{>>~{~!",
        "<<{~~{{>>~{~~!",
    ];

    /// The in-place solvers of XOR and EQU (the engine's `logic::tests::SOLVERS`).
    pub const IN_PLACE_XOR: &str = "<<<{,{~>>{~<~}}~!";
    pub const IN_PLACE_EQU: &str = "<<<{,{~>>{~<~}}~{~!";

    /// The Meta-stack bundle on an 8×8 world: Logic's full economy and a 32-byte tape.
    pub fn meta_stack_params() -> Params {
        Params {
            width: 8,
            height: 8,
            energy_payer: EnergyPayer::Initiator,
            energy_influx: 1024,
            energy_stock_cap: 65_536,
            steal_amount: 0,
            tasks: Tasks::Logic,
            task_every: 8,
            task_reward: 2048,
            logic_nand: LogicNand::Stack,
            meta_len: 32,
            meta_rate: 32.0 / 8192.0,
            meta_draw: life_engine::params::MetaDraw::Isa,
            meta_seed: life_engine::params::MetaSeed::OwnTape,
            ..Params::default()
        }
    }

    pub fn stack_solver(rung: usize) -> Vec<u8> {
        tape::parse(STACK_SOLVERS[rung], 32).unwrap()
    }

    #[test]
    fn the_fixed_sets_separate_the_ladder() {
        for set in FIXED_CASE_SETS {
            assert!(Cases::new(set).separates(), "{set:?}");
        }
    }

    #[test]
    fn the_fixed_sets_are_the_studys_draw() {
        let mut rng = life_engine::rng::seeded(0xdee9, 1, 0);
        for set in FIXED_CASE_SETS {
            assert_eq!(Cases::draw(&mut rng), Cases::new(set));
        }
    }

    #[test]
    fn each_stack_solver_is_credited_its_own_rung_on_all_six_sets() {
        let scorer = Scorer::for_params(&meta_stack_params());
        for rung in 0..LOGIC_TASKS.len() {
            assert_eq!(scorer.solid(&stack_solver(rung)), Rungs::one(rung));
        }
    }

    #[test]
    fn the_nand_and_the_floor_are_the_runs_own() {
        let stack = meta_stack_params();
        let in_place = Params {
            logic_nand: LogicNand::InPlace,
            ..stack.clone()
        };
        let xor = tape::parse(IN_PLACE_XOR, 32).unwrap();
        assert_eq!(Scorer::for_params(&in_place).solid(&xor), Rungs::one(8));
        assert!(!Scorer::for_params(&stack).solid(&xor).meets(DEEP));

        let deep_only = Params {
            task_floor: "xor".into(),
            ..stack.clone()
        };
        let nor = stack_solver(7);
        assert_eq!(Scorer::for_params(&stack).paid_units(&nor), 8);
        assert_eq!(Scorer::for_params(&deep_only).paid_units(&nor), 0);
        assert_eq!(
            Scorer::for_params(&deep_only).paid_units(&stack_solver(9)),
            16
        );
    }

    #[test]
    fn rungs_read_by_name() {
        assert_eq!(Rungs::parse("xor,equ").unwrap(), DEEP);
        assert_eq!(DEEP.names(), "xor+equ");
        assert_eq!(Rungs(0).names(), "-");
        assert!(Rungs::parse("xnor").is_err());
    }
}
