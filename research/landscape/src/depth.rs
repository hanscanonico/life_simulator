//! The topless assay as the readings apply it (`tasks = logic3 | logic4`): a run's own
//! instruction set and NAND, over its own `task_max_outputs` output slots (16 on an
//! out-compute run, the engine's 4 elsewhere), on six fixed case sets, a tape credited a rung
//! where every set credits it.

use life_engine::params::LogicNand;
use life_engine::topless::{self, Cases, Credit, Inputs, DEPTH_FLOOR, DEPTH_MAX_CASES};
use life_engine::{bff, OpSet, Params};
use std::fmt::Write;

type CaseValues = [[u8; 4]; DEPTH_MAX_CASES];

/// "Six fixed four-input case sets" of the topless-rise entry (2026-10-02, H-rise-code):
/// `topless::Cases::draw(Inputs::Four, ·)` six times in turn off `rng::seeded(0xdee9, 4, 0)`,
/// frozen here so no later engine change can move them.
pub const FIXED_SETS4: [CaseValues; 6] = [
    [
        [0xda, 0x81, 0x68, 0xf0],
        [0x70, 0x7b, 0xd3, 0x1d],
        [0x4f, 0x58, 0xe6, 0xc4],
        [0xa1, 0x9d, 0x8c, 0x75],
        [0xce, 0x0b, 0x52, 0x2f],
        [0x07, 0x76, 0x5b, 0x49],
    ],
    [
        [0x5a, 0x16, 0x41, 0xd8],
        [0x9c, 0x2f, 0xed, 0x66],
        [0x81, 0xa4, 0x17, 0x38],
        [0xed, 0x5e, 0x59, 0x3d],
        [0x23, 0xba, 0x5a, 0xad],
        [0xdc, 0x70, 0xc9, 0xc1],
    ],
    [
        [0xdc, 0xb9, 0x4d, 0x59],
        [0x13, 0x98, 0x78, 0xa6],
        [0x99, 0x0f, 0x35, 0x47],
        [0xa5, 0x2e, 0x47, 0xe1],
        [0x4b, 0x8d, 0xd8, 0x24],
        [0xcc, 0xe2, 0xb4, 0xfc],
    ],
    [
        [0x2f, 0xa2, 0x9b, 0x08],
        [0x16, 0xc7, 0x64, 0xfe],
        [0x9d, 0x2f, 0xd8, 0xce],
        [0xc8, 0x62, 0x63, 0xb0],
        [0xe0, 0x3c, 0xce, 0x75],
        [0x7a, 0xf0, 0x34, 0x2c],
    ],
    [
        [0x3d, 0xc5, 0x74, 0x2e],
        [0x25, 0x2b, 0x72, 0x1b],
        [0xc5, 0x66, 0xe1, 0x94],
        [0x4b, 0x1e, 0xb2, 0x37],
        [0xf9, 0xe4, 0xc9, 0x71],
        [0x11, 0x74, 0x4e, 0xe8],
    ],
    [
        [0x61, 0xa9, 0xf2, 0xf9],
        [0x9d, 0x4e, 0xc8, 0x30],
        [0x1a, 0x04, 0xd6, 0x4f],
        [0xab, 0xf7, 0x07, 0x31],
        [0x54, 0x91, 0x66, 0x1f],
        [0xb5, 0xdc, 0xcc, 0x45],
    ],
];

/// The three-input ladder's six sets, drawn the same way off `rng::seeded(0xdee9, 3, 0)`.
/// No entry locks them; they are the four-input rule carried to `logic3` worlds. The three
/// cases past the ladder's own are 0 and never run.
pub const FIXED_SETS3: [CaseValues; 6] = [
    [
        [0x74, 0x53, 0x1e, 0x00],
        [0x87, 0xc9, 0x63, 0x00],
        [0xaa, 0x4b, 0x39, 0x00],
        [0; 4],
        [0; 4],
        [0; 4],
    ],
    [
        [0x4d, 0x87, 0x63, 0x00],
        [0x5a, 0xe2, 0x8b, 0x00],
        [0xac, 0x99, 0x87, 0x00],
        [0; 4],
        [0; 4],
        [0; 4],
    ],
    [
        [0x27, 0xe4, 0xb1, 0x00],
        [0xf0, 0x9c, 0x55, 0x00],
        [0xac, 0xf0, 0xca, 0x00],
        [0; 4],
        [0; 4],
        [0; 4],
    ],
    [
        [0x39, 0xf0, 0x65, 0x00],
        [0x87, 0x55, 0x1b, 0x00],
        [0xd4, 0x78, 0x9a, 0x00],
        [0; 4],
        [0; 4],
        [0; 4],
    ],
    [
        [0xb8, 0x33, 0x96, 0x00],
        [0x4e, 0x1b, 0x8d, 0x00],
        [0x95, 0x4d, 0x74, 0x00],
        [0; 4],
        [0; 4],
        [0; 4],
    ],
    [
        [0x1b, 0x4d, 0xca, 0x00],
        [0x65, 0x95, 0xa3, 0x00],
        [0xca, 0xa9, 0xf0, 0x00],
        [0; 4],
        [0; 4],
        [0; 4],
    ],
];

/// The stream each ladder's fixed sets were drawn on: `rng::seeded(SEED, inputs, 0)`.
pub const FIXED_SETS_SEED: u64 = 0xdee9;

pub fn fixed_sets(inputs: Inputs) -> Vec<Cases> {
    let values = match inputs {
        Inputs::Three => FIXED_SETS3,
        Inputs::Four => FIXED_SETS4,
    };
    values.map(|set| Cases::new(inputs, set)).to_vec()
}

/// The rungs one tape is credited on all six sets, greatest truth table first.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Solid {
    pub inputs: Inputs,
    pub classes: Vec<u16>,
}

impl Solid {
    /// The deepest rung's minimal NAND count, `None` for no rung.
    pub fn depth(&self) -> Option<u32> {
        self.classes
            .iter()
            .map(|class| self.inputs.depth(*class))
            .max()
    }

    pub fn has(&self, class: u16) -> bool {
        self.classes.contains(&class)
    }

    /// Each rung as its truth table and depth, `-` for none.
    pub fn names(&self) -> String {
        if self.classes.is_empty() {
            return "-".into();
        }
        self.classes
            .iter()
            .map(|class| rung_name(self.inputs, *class))
            .collect::<Vec<_>>()
            .join(" ")
    }
}

/// A rung as `0x6996@12`, its least truth table and minimal NAND count, `@13+` at the
/// floor, where the count is only a lower bound.
pub fn rung_name(inputs: Inputs, class: u16) -> String {
    let mut name = match inputs {
        Inputs::Three => format!("{class:#04x}"),
        Inputs::Four => format!("{class:#06x}"),
    };
    let _ = write!(name, "@{}", inputs.depth(class));
    if inputs.at_floor(class) {
        name.push('+');
    }
    name
}

/// A depth as read, "13 or more" at the floor.
pub fn depth_name(depth: u32) -> String {
    if depth >= DEPTH_FLOOR {
        format!("{depth} or more")
    } else {
        depth.to_string()
    }
}

/// The topless assay of one run: its ladder, instruction set and NAND.
#[derive(Debug, Clone)]
pub struct DepthScorer {
    inputs: Inputs,
    sets: Vec<Cases>,
    ops: OpSet,
    nand: LogicNand,
    slots: usize,
}

impl DepthScorer {
    /// The run's scorer, `None` unless it runs the topless ladder.
    pub fn for_params(params: &Params) -> Option<Self> {
        let inputs = params.tasks.depth_inputs()?;
        Some(Self {
            inputs,
            sets: fixed_sets(inputs),
            ops: params.op_set(),
            nand: params.logic_nand,
            slots: params.assay_slots(),
        })
    }

    pub fn inputs(&self) -> Inputs {
        self.inputs
    }

    /// The output slots the assay reads: the run's `task_max_outputs`.
    pub fn slots(&self) -> usize {
        self.slots
    }

    pub fn on_set(&self, tape: &[u8], set: usize) -> Credit {
        topless::assay_upto(tape, &self.sets[set], self.ops, self.nand, self.slots)
    }

    /// The rungs credited on all six sets: what the readings call a tape's credit.
    pub fn solid(&self, tape: &[u8]) -> Solid {
        let mut classes = Vec::new();
        if tape.contains(&bff::EMIT) {
            classes = self.on_set(tape, 0).classes().collect();
            for set in 1..self.sets.len() {
                if classes.is_empty() {
                    break;
                }
                let credit = self.on_set(tape, set);
                classes.retain(|class| credit.classes().any(|held| held == *class));
            }
        }
        Solid {
            inputs: self.inputs,
            classes,
        }
    }
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use life_engine::params::Tasks;
    use life_engine::rng;

    #[test]
    fn the_fixed_sets_are_the_entrys_draw() {
        for (inputs, stream) in [(Inputs::Three, 3), (Inputs::Four, 4)] {
            let mut rng = rng::seeded(FIXED_SETS_SEED, stream, 0);
            for set in fixed_sets(inputs) {
                assert_eq!(Cases::draw(inputs, &mut rng), set);
                assert!(set.separates());
            }
        }
    }

    #[test]
    fn only_a_topless_run_has_a_depth_scorer() {
        let params = |tasks| Params {
            tasks,
            ..Params::default()
        };
        assert!(DepthScorer::for_params(&params(Tasks::Logic)).is_none());
        let scorer = DepthScorer::for_params(&params(Tasks::Logic4)).unwrap();
        assert_eq!(scorer.inputs(), Inputs::Four);
        assert_eq!(
            scorer.solid(b"<<{~"),
            Solid {
                inputs: Inputs::Four,
                classes: vec![],
            }
        );
    }

    /// A random tape credited NOT (depth 2) on the first five four-input sets and only its
    /// depth-1 rung on the sixth: credited depth 1, not 2, since every set must agree.
    #[test]
    fn a_rung_is_credited_only_where_all_six_sets_credit_it() {
        let params = Params {
            tasks: Tasks::Logic4,
            logic_nand: LogicNand::Stack,
            ..Params::default()
        };
        let scorer = DepthScorer::for_params(&params).unwrap();
        let tape = crate::tape::parse("<{{![0!~.]{}[", 32).unwrap();
        let depths: Vec<Option<u32>> = (0..6)
            .map(|set| scorer.on_set(&tape, set).depth())
            .collect();
        assert_eq!(
            depths,
            [Some(2), Some(2), Some(2), Some(2), Some(2), Some(1)]
        );
        assert_eq!(scorer.solid(&tape).depth(), Some(1));
    }

    /// The out-compute bundle (the engine's `predatory_params`) on the Meta-stack world: an
    /// unpaid four-input ladder over 16 slots, its metabolism tape 128 bytes rather than the
    /// sweep's 32 so `echo_then_xor4`'s 123 fit.
    pub fn out_compute_params() -> Params {
        Params {
            tasks: Tasks::Logic4,
            task_reward: 0,
            task_max_outputs: 16,
            meta_len: 128,
            ..crate::score::tests::meta_stack_params()
        }
    }

    /// The engine's wider-assay tape (`topless::tests`): x emitted four times, then XOR4's
    /// minimal witness compiled, so its fifth slot holds a depth-12 class.
    pub fn echo_then_xor4() -> Vec<u8> {
        let mut tape = vec![bff::HEAD0_LEFT];
        tape.extend([bff::EMIT; 4]);
        tape.push(bff::HEAD0_RIGHT);
        tape.extend(crate::bearing::tests::compile(
            Inputs::Four,
            "f0123041425356789abacbcde",
        ));
        tape
    }

    #[test]
    fn an_out_compute_run_reads_its_sixteen_slots_past_the_fourth() {
        let tape = echo_then_xor4();
        let four = DepthScorer::for_params(&Params {
            task_max_outputs: 4,
            ..out_compute_params()
        })
        .unwrap();
        let sixteen = DepthScorer::for_params(&out_compute_params()).unwrap();
        assert_eq!((four.slots(), sixteen.slots()), (4, 16));
        assert_eq!(four.solid(&tape).depth(), Some(0));
        let wide = sixteen.solid(&tape);
        assert_eq!(wide.depth(), Some(12));
        assert!(wide.has(Inputs::Four.class_of(0x6996)));
    }

    #[test]
    fn rungs_and_depths_are_named_with_the_floor() {
        assert_eq!(rung_name(Inputs::Three, 0x16), "0x16@10");
        assert_eq!(rung_name(Inputs::Four, 0x0116), "0x0116@13+");
        assert_eq!(depth_name(12), "12");
        assert_eq!(depth_name(13), "13 or more");
    }
}
