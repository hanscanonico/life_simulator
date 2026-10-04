//! Simulation parameters: names, defaults, validated ranges and the JSON schema Rails
//! reads, all in one place (`docs/DESIGN.md` §3, "parameters are data").

use crate::bff::{AssayOps, OpSet};
use crate::logic::{FIRST_DEEP_TASK, LOGIC_CASE_DRAWS, LOGIC_TASKS};
use crate::metrics::{
    TRANSITION_BASELINE_EPOCHS, TRANSITION_HOLD_SAMPLES, TRANSITION_MAX_OP_DENSITY,
    TRANSITION_MIN_ALPHABET_SIZE, TRANSITION_RELATIVE_FRACTION, TRANSITION_THRESHOLD,
};
use crate::replicator::{
    SELF_REP_AGREEMENT_DENOMINATOR, SELF_REP_AGREEMENT_NUMERATOR, SELF_REP_GENERATIONS,
    SELF_REP_SAMPLE_CELLS, SELF_REP_TRIALS,
};
use crate::task::{
    TASKS, TASK_CASES, TASK_CASE_DRAWS, TASK_INPUT_RANGE, TASK_MAX_OUTPUTS, TASK_MAX_OUTPUTS_LIMIT,
    TASK_STEPS,
};
use crate::topless::{Inputs, DEPTH_CASE_DRAWS, DEPTH_FLOOR, DEPTH_UNITS, READS_PER_ROW};
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Substrate {
    /// The spatial BFF program soup — the research substrate.
    Soup,
    /// Conway's `B3/S23` — shipped because visitors recognise it.
    Life,
}

/// How the world varies from place to place (`docs/DESIGN.md` §1.3, sweep 7; why these
/// two shapes and no others is the 2026-09-14 design-record entry). `Uniform` is the
/// default and the world every earlier run lived in: one mutation rate everywhere.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Structure {
    Uniform,
    /// A triangle across the columns: driest at column 0, wettest half a world east,
    /// falling back to dry as it comes round.
    Gradient,
    /// Four quadrants alternating dry and wet.
    Patchwork,
}

/// What an interaction executes (`docs/DESIGN.md` §1.1). `Concat` is the default and the
/// substrate every earlier run lived in: the whole concatenation is the program. `Host`
/// makes the pairing asymmetric — only the first tape's bytes are code, and the partner is
/// substrate the program reads and writes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Interaction {
    Concat,
    Host,
}

/// Who pays for an interaction under an energy stock (`docs/DESIGN.md` §1.1; why it is a
/// parameter is the 2026-10-01 design-record entry). `Pair` is the default and the rule
/// every earlier stocked run paid by: the interaction runs on the poorer cell's stock and
/// both cells are debited what ran. `Initiator` charges the cell that opens the interaction
/// alone a fixed price of `max_steps`, and passes a cell over as initiator until its stock
/// can pay it, so a cell's income is the rate it initiates at.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum EnergyPayer {
    Pair,
    Initiator,
}

/// Which tasks a soup's cells are assayed on (`docs/DESIGN.md` §1.1, "Tasks and the emit
/// op"; the 2026-10-01 design-record entry on the task assay). `Off` is the default and the
/// soup every earlier run lived in. `Arith` assays every cell on the arithmetic ladder of
/// `task::TASKS` every `task_every` epochs and pays `task_reward` per unit it earns into
/// the cell's stock. `Logic` does the same on the logic ladder of `logic::LOGIC_TASKS`,
/// with `bff::NAND` an instruction inside its assay. `Logic3` and `Logic4` are the topless
/// ladder of `topless`: the logic assay on three or four inputs, crediting every
/// non-constant function of them and paying each by its minimal NAND count.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Tasks {
    Off,
    Arith,
    Logic,
    Logic3,
    Logic4,
}

impl Tasks {
    /// The name the params give this ladder.
    pub fn name(self) -> &'static str {
        match self {
            Self::Off => "off",
            Self::Arith => "arith",
            Self::Logic => "logic",
            Self::Logic3 => "logic3",
            Self::Logic4 => "logic4",
        }
    }

    /// The names of this ladder's rungs `task_floor` may name, lowest first: none with tasks
    /// off, and on the topless ladders ECHO alone, since a floor there pays every rung.
    pub fn rungs(self) -> Vec<&'static str> {
        match self {
            Self::Off => Vec::new(),
            Self::Arith => TASKS.iter().map(|task| task.name).collect(),
            Self::Logic => LOGIC_TASKS.iter().map(|task| task.name).collect(),
            Self::Logic3 | Self::Logic4 => vec![LOGIC_TASKS[0].name],
        }
    }

    /// Whether this ladder runs the logic assay's machine, `~` an instruction in it: the
    /// two-input logic ladder or a topless one.
    pub fn is_logic(self) -> bool {
        matches!(self, Self::Logic | Self::Logic3 | Self::Logic4)
    }

    /// How many inputs the topless ladder reads, `None` on every other.
    pub fn depth_inputs(self) -> Option<Inputs> {
        match self {
            Self::Logic3 => Some(Inputs::Three),
            Self::Logic4 => Some(Inputs::Four),
            Self::Off | Self::Arith | Self::Logic => None,
        }
    }
}

/// `meta_rate`'s default, the design study's 32 × the replicating tape's 1/8192 of the
/// Logic sweep (`docs/design_record.md`, 2026-10-02, Meta-stack slice B).
const META_RATE_DEFAULT: f64 = 32.0 / 8192.0;
/// The longest metabolism tape a run may carry, at the start or grown, which also bounds
/// what a snapshot may claim to hold. Room the design study's pilot 8 did not reach
/// (`docs/design_record.md`, 2026-10-04, Genes slice A).
pub const META_LEN_MAX: u32 = 8192;
/// `meta_min_len`'s default, the floor the design study's growable channel deleted to.
const META_MIN_LEN_DEFAULT: u32 = 8;
/// `meta_seg_max`'s default, the study's 1..=16-byte duplicated and deleted segments.
const META_SEG_MAX_DEFAULT: u32 = 16;

/// What the NAND byte `~` writes inside the logic assay (`docs/DESIGN.md` §1.1; the
/// 2026-10-02 design-record entry on the stack NAND). `InPlace` is the default and the NAND
/// every earlier logic run assayed with: `B[head0] = ¬(B[head0] ∧ B[head1])`, h0's operand
/// lost. `Stack` writes the result to `B[head0 − 1]` and moves head0 onto it, so both operands
/// are kept and a chain of NANDs stacks leftward.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LogicNand {
    InPlace,
    Stack,
}

impl LogicNand {
    /// The logic assay's machine under this NAND.
    pub fn assay_ops(self) -> AssayOps {
        match self {
            Self::InPlace => AssayOps::EmitNand,
            Self::Stack => AssayOps::EmitStackNand,
        }
    }
}

/// Which relation between two cells' computations lets one take energy from the other
/// (`docs/DESIGN.md` §1.1, "Predation"; the 2026-10-03 design-record entry). `Off` is the
/// default and the soup every earlier run lived in. Under the other three a cell that acts
/// picks a partner by the soup's own rule and, where the relation holds, takes up to
/// `predation_transfer` of its stock: `SubsetClass` when every input-permutation class the
/// partner's metabolism tape computes is one the actor's computes too, `Equal` when the two
/// sets are the same, `Shadow` on a coin at `predation_shadow_p` that reads no
/// computation at all, and `Count` when the partner computes strictly fewer classes than
/// the actor, whichever they are (out-count, 2026-10-04).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Predation {
    Off,
    SubsetClass,
    Equal,
    Shadow,
    Count,
}

/// Every name `task_floor` may take, the arithmetic ladder's rungs then the logic ladder's
/// not already named; which of them a run may choose is set by its `tasks`. Both ladders
/// begin at ECHO, the default.
const TASK_FLOORS: &[&str] = &[
    "echo", "inc", "dec", "add", "sub", "not", "double", "mul", "nand", "and", "orn", "or", "andn",
    "nor", "xor", "equ",
];

/// How a lineage tag follows descent (`docs/DESIGN.md` §1.2; why it is a parameter is the
/// 2026-09-25 design-record entry). `Aligned` is the default and the rule every earlier
/// run's tags were inherited by: a tape is compared with the two arriving tapes byte for
/// byte. `Oriented` compares it with each arriving tape either way round, so a cell a
/// reverse copier overwrote takes the copier's tag.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LineageRule {
    Aligned,
    Oriented,
}

/// What a metabolism-tape byte is replaced by when it mutates (`docs/DESIGN.md` §1.1, "The
/// metabolism tape"). `Uniform` draws any byte, as `mutation_rate` does on a tape. `Isa`
/// draws one of 14 values at 1/14 each: the ten ops, `!`, `~`, 0, or one byte drawn
/// uniformly from the 243 no-ops that are none of those, so the logic assay's instructions
/// arrive as often as a no-op does.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MetaDraw {
    Uniform,
    Isa,
}

/// What a cell's metabolism tape holds when the tape is switched on: at epoch 0 of a
/// founding run, or at descent from a parent that carried none. `Zeros` is an empty tape;
/// `OwnTape` is the first `meta_len` bytes of the cell's own replicating tape at that
/// moment, zero-padded past a shorter tape.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MetaSeed {
    Zeros,
    OwnTape,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Init {
    Random,
    Zero,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Params {
    pub substrate: Substrate,
    pub width: u32,
    pub height: u32,
    pub tape_len: u32,
    /// The longest a cell's tape may grow to; `0` (the default) turns growth off and
    /// every tape stays `tape_len` bytes for the whole run (DESIGN §1.3, sweep 8).
    pub max_tape_len: u32,
    /// Moore-neighbourhood radius; `0` means well-mixed (any cell in the world).
    pub radius: u32,
    pub max_steps: u32,
    /// Instruction energy one cell may spend per epoch; `0` (the default) turns the cost
    /// off and the soup runs as it always has (DESIGN §1.3, sweep 6).
    pub energy_per_epoch: u32,
    /// Instruction energy every cell is given at the start of every epoch, added to a
    /// stock that carries across epochs up to `energy_stock_cap`; `0` (the default) turns
    /// the stock economy off and no stock is allocated at all (DESIGN §1.1).
    pub energy_influx: u32,
    /// The most instruction energy one cell's stock may hold. Read only once an influx is
    /// set, and never below it.
    pub energy_stock_cap: u32,
    /// Who pays for an interaction out of the stock: both cells what ran (`pair`, the
    /// default and the rule of every earlier stocked run), or the initiator alone a fixed
    /// `max_steps` (`initiator`). Read only once an influx is set, and refused without one.
    pub energy_payer: EnergyPayer,
    /// Instruction energy one steal op moves out of the partner cell's stock; `0` (the
    /// default) leaves the steal byte the no-op it is in the substrate of DESIGN §1.1 and
    /// nothing is ever moved (DESIGN §1.1).
    pub steal_amount: u32,
    /// The share of what a steal moves that is destroyed in transit. Read only once a
    /// `steal_amount` is set, so the default is no second off switch.
    pub steal_loss: f64,
    /// The task ladder cells are assayed on: none (`off`, the default), or the arithmetic
    /// ladder (`arith`).
    pub tasks: Tasks,
    /// Epochs between assays: a cell is assayed at the start of every epoch that is a
    /// multiple of this.
    pub task_every: u32,
    /// Energy paid into a cell's stock per unit of the tasks it is credited with at one
    /// assay; `0` (the default) pays nothing and runs no assay at all.
    pub task_reward: u32,
    /// The lowest rung of the ladder that is paid: rungs below it are still assayed but
    /// earn nothing. `echo` (the default) is the first rung of both ladders, so every rung
    /// is paid.
    pub task_floor: String,
    /// What `~` writes in the logic assay: in place under head0 (`in_place`, the default),
    /// or left of head0 with head0 following (`stack`). Refused away from the logic ladders.
    pub logic_nand: LogicNand,
    /// The deepest rung the topless ladder pays as deep as it is: a rung deeper than this
    /// is paid as a rung of this depth. `0` (the default) caps nothing. Refused away from
    /// `tasks = logic3` and `logic4`.
    pub task_depth_cap: u32,
    /// How many output slots the topless assay reads: `TASK_MAX_OUTPUTS` (the default, the
    /// engine's rule) up to `TASK_MAX_OUTPUTS_LIMIT`. Refused above the default anywhere
    /// but an unpaid topless ladder, so no paid run reads a wider assay.
    pub task_max_outputs: u32,
    /// The interaction rule that reads what tapes compute: none (`off`, the default), or
    /// one of the relations of `Predation`.
    pub predation: Predation,
    /// The most stock one predation moves out of the partner; `0` (the default) moves
    /// nothing, and the pass does not run.
    pub predation_transfer: u32,
    /// The share of what a predation moves that is destroyed in transit, as `steal_loss`.
    pub predation_loss: f64,
    /// The predation pass's period: each cell acts with probability 1 in this every epoch,
    /// and the cases a cell's computation is read on are redrawn every this many epochs.
    pub predation_every: u32,
    /// The coin `predation = shadow` decides an encounter by.
    pub predation_shadow_p: f64,
    /// The enabled instruction set: the ops a run executes, as a subset of the ten BFF
    /// bytes. A byte whose op is not enabled is a no-op (DESIGN §1.3, sweep 5).
    pub ops: String,
    /// Probability that a given byte is replaced by a random one, per byte per epoch.
    pub mutation_rate: f64,
    /// How the world varies from place to place; `uniform` (the default) is the world of
    /// DESIGN §1.1, where `mutation_rate` is the rate everywhere (DESIGN §1.3, sweep 7).
    pub structure: Structure,
    /// How far a structured world's cells lean from `mutation_rate`, as a fraction of it:
    /// the driest cell runs at `1 - amplitude` times the rate and the wettest at
    /// `1 + amplitude`. Read only once a `structure` is set, so the default is no second
    /// off switch.
    pub structure_amplitude: f64,
    /// What an interaction executes: the whole concatenation (`concat`, the default and
    /// the substrate of DESIGN §1.1), or the first tape's bytes only (`host`).
    pub interaction: Interaction,
    /// How a lineage tag follows descent: byte for byte (`aligned`, the default and the
    /// rule of every earlier run), or either way round (`oriented`). Moves no byte.
    pub lineage_rule: LineageRule,
    /// Bytes of each soup cell's metabolism tape: a second tape the soup never executes,
    /// which the logic assay reads instead of the replicating tape. `0` (the default)
    /// allocates none, and the run is the run it always was.
    pub meta_len: u32,
    /// Probability a metabolism-tape byte mutates, per byte per epoch, on the tape's own
    /// stream. Read only once `meta_len` is set.
    pub meta_rate: f64,
    /// What a mutated metabolism-tape byte becomes. Read only once `meta_len` is set.
    pub meta_draw: MetaDraw,
    /// What a metabolism tape holds when it is switched on. Read only once `meta_len` is
    /// set.
    pub meta_seed: MetaSeed,
    /// The longest a metabolism tape may grow to, from `meta_len`; `0` (the default) and
    /// `meta_len` itself keep every tape `meta_len` bytes for the whole run.
    pub meta_max_len: u32,
    /// The shortest a deletion may leave a metabolism tape. Read only on a channel that
    /// grows.
    pub meta_min_len: u32,
    /// The probability an inherited metabolism tape has a duplicate of one of its segments
    /// appended. Read only on a channel that grows.
    pub meta_dup: f64,
    /// The probability an inherited metabolism tape loses one of its segments, after any
    /// duplication. Read only on a channel that grows.
    pub meta_del: f64,
    /// The longest segment a duplication or deletion moves. Read only on a channel that
    /// grows.
    pub meta_seg_max: u32,
    /// The gene length the topless assay splits a metabolism tape into, each gene run alone
    /// and the tape credited the union; `0` (the default) runs the tape whole.
    pub meta_genes: u32,
    pub init: Init,
    pub sample_every: u32,
    pub top_k: u32,
    pub snapshot_every: u32,
}

impl Default for Params {
    fn default() -> Self {
        Self {
            substrate: Substrate::Soup,
            width: 128,
            height: 128,
            tape_len: 64,
            max_tape_len: 0,
            radius: 1,
            max_steps: 8192,
            energy_per_epoch: 0,
            energy_influx: 0,
            energy_stock_cap: 0,
            energy_payer: EnergyPayer::Pair,
            steal_amount: 0,
            steal_loss: 0.5,
            tasks: Tasks::Off,
            task_every: 8,
            task_reward: 0,
            task_floor: TASK_FLOORS[0].to_string(),
            logic_nand: LogicNand::InPlace,
            task_depth_cap: 0,
            task_max_outputs: TASK_MAX_OUTPUTS as u32,
            predation: Predation::Off,
            predation_transfer: 0,
            predation_loss: 0.5,
            predation_every: 8,
            predation_shadow_p: 0.3,
            ops: crate::bff::OPS.iter().map(|op| *op as char).collect(),
            mutation_rate: 1.0 / 4096.0,
            structure: Structure::Uniform,
            structure_amplitude: 0.5,
            interaction: Interaction::Concat,
            lineage_rule: LineageRule::Aligned,
            meta_len: 0,
            meta_rate: META_RATE_DEFAULT,
            meta_draw: MetaDraw::Uniform,
            meta_seed: MetaSeed::Zeros,
            meta_max_len: 0,
            meta_min_len: META_MIN_LEN_DEFAULT,
            meta_dup: 0.0,
            meta_del: 0.0,
            meta_seg_max: META_SEG_MAX_DEFAULT,
            meta_genes: 0,
            init: Init::Random,
            sample_every: 10,
            top_k: 16,
            snapshot_every: 100,
        }
    }
}

enum Kind {
    Choice(&'static [&'static str]),
    /// A string naming a subset of these values, each at most once, at least one.
    Subset(&'static [&'static str]),
    Integer {
        min: f64,
        max: f64,
    },
    Float {
        min: f64,
        max: f64,
    },
}

struct Field {
    name: &'static str,
    kind: Kind,
    doc: &'static str,
}

/// The one description of every parameter: `validate` and `schema_json` both read it, so
/// a range can never disagree with the schema Rails renders.
const FIELDS: &[Field] = &[
    Field {
        name: "substrate",
        kind: Kind::Choice(&["soup", "life"]),
        doc: "Which world rule to run: the BFF program soup, or Conway's Game of Life.",
    },
    Field {
        name: "width",
        kind: Kind::Integer {
            min: 4.0,
            max: 1024.0,
        },
        doc: "World width in cells; the world is a torus.",
    },
    Field {
        name: "height",
        kind: Kind::Integer {
            min: 4.0,
            max: 1024.0,
        },
        doc: "World height in cells; the world is a torus.",
    },
    Field {
        name: "tape_len",
        kind: Kind::Integer {
            min: 8.0,
            max: 1024.0,
        },
        doc: "Bytes of tape held by one soup cell. Ignored by the life substrate.",
    },
    Field {
        name: "max_tape_len",
        kind: Kind::Integer {
            min: 0.0,
            max: 1024.0,
        },
        doc: "The longest a soup cell's tape may grow to, through the programs' own \
              copying: a head stepping right off the end of an interaction appends a byte \
              instead of wrapping while there is room. 0 turns growth off, which is the \
              fixed-length substrate of DESIGN 1.1, and so does any value equal to \
              tape_len; below tape_len it is refused.",
    },
    Field {
        name: "radius",
        kind: Kind::Integer {
            min: 0.0,
            max: 64.0,
        },
        doc: "Moore-neighbourhood radius an interaction reaches; 0 means well-mixed. \
              A positive radius must fit the torus: 2*radius + 1 <= min(width, height).",
    },
    Field {
        name: "max_steps",
        kind: Kind::Integer {
            min: 1.0,
            max: 1_048_576.0,
        },
        doc: "Instruction budget for one interaction between two tapes.",
    },
    Field {
        name: "energy_per_epoch",
        kind: Kind::Integer {
            min: 0.0,
            max: 1_048_576.0,
        },
        doc: "Instructions one cell may pay for per epoch, refilled at the start of every \
              epoch; an interaction runs on what the poorer of its two cells has left. \
              0 turns the cost off, which is the substrate of DESIGN 1.1.",
    },
    Field {
        name: "energy_influx",
        kind: Kind::Integer {
            min: 0.0,
            max: 1_048_576.0,
        },
        doc: "Instructions one cell is given per epoch, added to a stock that carries \
              across epochs up to energy_stock_cap rather than being refilled to it. Under \
              the default energy_payer an interaction runs on what the poorer of its two \
              cells holds, both are \
              debited what ran, and a cell whose stock is empty is not executed until it \
              has recharged. 0 turns the stock off, which is the substrate of DESIGN 1.1.",
    },
    Field {
        name: "energy_stock_cap",
        kind: Kind::Integer {
            min: 0.0,
            max: 1_048_576.0,
        },
        doc: "The most instruction energy one cell's stock may hold, which is also the \
              stock every cell starts the run with, so the world's total energy never \
              exceeds cell count times this. Read only once energy_influx is set, and \
              refused below it.",
    },
    Field {
        name: "energy_payer",
        kind: Kind::Choice(&["pair", "initiator"]),
        doc: "Who pays for an interaction out of the energy stock. pair runs it on what \
              the poorer of its two cells holds and debits both what ran, which is the \
              economy of DESIGN 1.1 every earlier stocked run used. initiator charges the \
              cell whose turn it is alone a fixed max_steps, whatever ran, and passes a \
              cell over as initiator until its stock holds that price; its partner is \
              never gated and never debited, so a cell's income is the rate it initiates \
              at. initiator needs an energy_influx, an energy_stock_cap of at least \
              max_steps, and no energy_per_epoch.",
    },
    Field {
        name: "steal_amount",
        kind: Kind::Integer {
            min: 0.0,
            max: 1_048_576.0,
        },
        doc: "Instruction energy one steal op moves out of the partner cell's stock into \
              the stock of the cell whose code is executing, less the steal_loss destroyed \
              in transit. A steal takes what the partner holds when that is less, and \
              nothing at all from an empty one. 0 turns the op off, which is the substrate \
              of DESIGN 1.1, and any amount needs an energy_influx to have a stock to \
              steal from.",
    },
    Field {
        name: "steal_loss",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "The share of what a run's steal ops move that is destroyed in transit: the \
              thief receives the rest, rounded down, so theft is never worth more to the \
              thief than it costs the world. Read only once steal_amount is set.",
    },
    Field {
        name: "tasks",
        kind: Kind::Choice(&["off", "arith", "logic", "logic3", "logic4"]),
        doc: "Which tasks a soup cell is assayed on. off assays nothing, which is the \
              substrate of DESIGN 1.1. arith runs each cell's tape alone, on two small \
              inputs at the end of a buffer twice its length, with ! emitting the byte \
              under head0, and credits the tasks of an arithmetic ladder (echo, inc, dec, \
              add, sub, not, double, mul) that one of its outputs computes in all three \
              cases. logic runs the same assay on two whole-byte inputs, with ~ also \
              writing the NAND of the bytes under the two heads under head0, and credits \
              the tasks of a logic ladder (echo, not, nand, and, orn, or, andn, nor, xor, \
              equ). logic3 and logic4 run the logic assay with a third input z one byte \
              left of y, and a fourth w one byte left of z under logic4, and credit every \
              non-constant function of the inputs that an output computes on every bit \
              column of its cases, three under logic3 and six under logic4, drawn so each \
              combination of the inputs is read at three different bit positions; each \
              class of functions equal up to a permutation of the inputs is a rung of its \
              own, worth its minimal NAND count. \
              Outside the assay ! and ~ are never instructions, and ~ is never one under \
              arith. Refused on life.",
    },
    Field {
        name: "task_every",
        kind: Kind::Integer {
            min: 1.0,
            max: 1_000_000.0,
        },
        doc: "Epochs between task assays: cells are assayed at the start of every epoch \
              that is a multiple of this. Read only once a task_reward is set.",
    },
    Field {
        name: "task_reward",
        kind: Kind::Integer {
            min: 0.0,
            max: 1_048_576.0,
        },
        doc: "Instruction energy paid into a cell's stock, before that epoch's influx and \
              never past energy_stock_cap, per unit of the tasks its tape is credited \
              with at an assay, at or above task_floor; the arith ladder's units are 1, 2, \
              2, 4, 4, 8, 8 and 16, the logic ladder's 1, 1, 1, 2, 2, 4, 4, 8, 8 and 16, and \
              a logic3 or logic4 rung of minimal NAND count d is worth the square root of \
              2^d rounded, 1, 1, 2, 3, 4, 6, 8, 11, 16, 23, 32, 45, 64 and 91 for d = 0 to \
              13, once per distinct rung. 0 pays \
              nothing and runs no assay, so the run is the same run as with tasks off. \
              Any reward needs tasks on and an energy_influx to have a stock to pay into.",
    },
    Field {
        name: "task_floor",
        kind: Kind::Choice(TASK_FLOORS),
        doc: "The lowest rung of the task ladder that is paid. Every rung is still \
              assayed, but those below this one earn nothing. It must name a rung of the \
              ladder tasks chooses: echo, inc, dec, add, sub, not, double or mul under \
              arith; echo, not, nand, and, orn, or, andn, nor, xor or equ under logic. \
              echo is the first rung of both, so it pays every rung; with tasks off, \
              logic3 or logic4 nothing else is accepted.",
    },
    Field {
        name: "logic_nand",
        kind: Kind::Choice(&["in_place", "stack"]),
        doc: "What ~ writes in the logic assay. in_place writes the NAND of the bytes under \
              the two heads under head0, the NAND every earlier logic run assayed with. \
              stack writes it one byte left of head0, wrapping as < does, and moves head0 \
              onto it, so both operands are kept and a chain of NANDs stacks its results \
              leftward. Outside the logic assay ~ is a no-op either way. Only tasks logic, \
              logic3 and logic4 accept anything but in_place.",
    },
    Field {
        name: "task_depth_cap",
        kind: Kind::Integer {
            min: 0.0,
            max: DEPTH_FLOOR as f64,
        },
        doc: "The deepest rung logic3 and logic4 pay as deep as it is: a rung whose minimal \
              NAND count is above this is paid as a rung of this count. 0 caps nothing. \
              Only tasks logic3 and logic4 accept anything but 0.",
    },
    Field {
        name: "task_max_outputs",
        kind: Kind::Integer {
            min: TASK_MAX_OUTPUTS as f64,
            max: TASK_MAX_OUTPUTS_LIMIT as f64,
        },
        doc: "How many outputs a case of the logic3 or logic4 assay may emit before it \
              stops, and so how many output slots are read for rungs: by the predation \
              pass, the depth readings and the logic readings. The first four read what \
              they always read, so a wider assay only adds rungs. Anything above 4 needs \
              tasks logic3 or logic4 and a task_reward of 0: no paid run reads it.",
    },
    Field {
        name: "predation",
        kind: Kind::Choice(&["off", "subset_class", "equal", "shadow", "count"]),
        doc: "An interaction rule that reads what metabolism tapes compute and names no \
              computation. Every epoch, before the influx, each cell acts with probability \
              1 in predation_every, in an order of its own, and picks a partner by the soup's \
              own neighbour rule; where the relation holds it takes up to predation_transfer \
              of the partner's stock, predation_loss of what moves destroyed, never past \
              energy_stock_cap. subset_class: every input-permutation class the partner's \
              metabolism tape computes on the logic3 or logic4 assay, over task_max_outputs \
              slots, is one the actor's computes too, so a tape computing nothing is \
              everyone's prey and two tapes computing the same are each other's. equal: the \
              two sets are the same. shadow: a coin at predation_shadow_p, reading nothing. \
              count: the partner computes strictly fewer classes than the actor, whichever \
              they are, so silence is prey and two tapes computing as many are not. Under \
              meta_genes every relation reads the union of the genes' classes. The cases are drawn on the pass's own stream every predation_every epochs. \
              off runs no pass, which is the substrate of DESIGN 1.1. Anything but off needs \
              a metabolism tape, an energy_influx, energy_payer initiator, tasks logic3 or \
              logic4, and a task_reward of 0.",
    },
    Field {
        name: "predation_transfer",
        kind: Kind::Integer {
            min: 0.0,
            max: 1_048_576.0,
        },
        doc: "The most stock one predation takes out of its partner: what the partner holds \
              when that is less. 0 moves nothing and runs no pass. Read only once predation \
              is set.",
    },
    Field {
        name: "predation_loss",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "The share of what a predation moves that is destroyed in transit: the actor \
              receives the rest, rounded down, as a steal op's thief does. Read only once \
              predation is set.",
    },
    Field {
        name: "predation_every",
        kind: Kind::Integer {
            min: 1.0,
            max: 1_000_000.0,
        },
        doc: "The predation pass's period: each cell acts with probability 1 in this every \
              epoch, so stocks are met at every phase of the initiation cycle, and the cases \
              computations are read on are redrawn every this many epochs. Read only once \
              predation is set.",
    },
    Field {
        name: "predation_shadow_p",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "The probability an encounter moves energy under predation shadow, a coin that \
              reads no computation. Read only under predation shadow.",
    },
    Field {
        name: "ops",
        kind: Kind::Subset(&["<", ">", "{", "}", "+", "-", ".", ",", "[", "]"]),
        doc: "The BFF instructions this run executes, as a string of distinct op bytes. \
              A byte whose op is left out is a no-op, like any non-instruction byte.",
    },
    Field {
        name: "mutation_rate",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "Probability a byte is replaced by a random byte, per byte per epoch. \
              Applies to every substrate: the ordinary Game of Life needs 0.",
    },
    Field {
        name: "structure",
        kind: Kind::Choice(&["uniform", "gradient", "patchwork"]),
        doc: "How the world varies from place to place: uniform runs one mutation rate \
              everywhere, which is the world of DESIGN 1.1; gradient runs a triangle \
              across the columns, driest at column 0 and wettest half a world east; \
              patchwork runs four quadrants alternating dry and wet.",
    },
    Field {
        name: "structure_amplitude",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "How far a structured world's cells lean from mutation_rate, as a fraction \
              of it: the driest cell runs at 1 - amplitude times the rate and the wettest \
              at 1 + amplitude.",
    },
    Field {
        name: "interaction",
        kind: Kind::Choice(&["concat", "host"]),
        doc: "What an interaction executes: concat runs the whole concatenation of the \
              two tapes, which is the substrate of DESIGN 1.1; host runs the first tape's \
              bytes only, leaving the partner as data the program reads and writes. Both \
              heads range over the whole pair either way.",
    },
    Field {
        name: "lineage_rule",
        kind: Kind::Choice(&["aligned", "oriented"]),
        doc: "How a soup cell's lineage tag follows descent. After an interaction a cell \
              takes its partner's tag when its tape ends strictly closer, by Hamming \
              distance, to the tape its partner arrived with than to its own. aligned \
              compares byte for byte, which is the rule of DESIGN 1.2 every earlier run \
              used; oriented takes each distance as the smaller of the arriving tape's and \
              its reverse's, so a cell overwritten by a reverse copy takes the copier's \
              tag. Moves no byte of the world: only the lineage tags and the readings \
              made of them.",
    },
    Field {
        name: "meta_len",
        kind: Kind::Integer {
            min: 0.0,
            max: META_LEN_MAX as f64,
        },
        doc: "Bytes of each soup cell's metabolism tape: a second tape the soup never \
              executes, which the logic assay reads instead of the replicating tape. It is \
              copied whole from the initiator onto its partner whenever an interaction \
              leaves the partner's tape a near copy of the initiator's, at least 90% of its \
              bytes in either orientation, and mutates on its own at meta_rate. 0 turns it \
              off, which is the substrate of DESIGN 1.1; any length needs tasks logic, \
              logic3 or logic4.",
    },
    Field {
        name: "meta_rate",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "Probability a metabolism-tape byte mutates, per byte per epoch, on a random \
              stream of its own. Read only once meta_len is set.",
    },
    Field {
        name: "meta_draw",
        kind: Kind::Choice(&["uniform", "isa"]),
        doc: "What a mutated metabolism-tape byte becomes: uniform draws any byte; isa \
              draws each of the ten ops, the emit byte !, the NAND byte ~, 0 and one random \
              no-op at 1/14. Read only once meta_len is set.",
    },
    Field {
        name: "meta_seed",
        kind: Kind::Choice(&["zeros", "own_tape"]),
        doc: "What each cell's metabolism tape holds when the tape is switched on, at \
              epoch 0 or at descent from a parent that carried none: zeros, or the first \
              meta_len bytes of the cell's own replicating tape. Read only once meta_len \
              is set.",
    },
    Field {
        name: "meta_max_len",
        kind: Kind::Integer {
            min: 0.0,
            max: META_LEN_MAX as f64,
        },
        doc: "The longest a metabolism tape may grow to. Every tape starts at meta_len \
              bytes; at each inheritance, the inherited copy has a duplicate of one of its \
              segments appended with probability meta_dup, never past this length, then \
              loses one of its segments with probability meta_del, never below meta_min_len. \
              0 keeps the channel fixed at meta_len, and so does meta_len itself; below \
              meta_len it is refused. Read only once meta_len is set.",
    },
    Field {
        name: "meta_min_len",
        kind: Kind::Integer {
            min: 1.0,
            max: META_LEN_MAX as f64,
        },
        doc: "The shortest a deletion may leave a metabolism tape, at most meta_len. Read \
              only on a channel that grows (meta_max_len above meta_len).",
    },
    Field {
        name: "meta_dup",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "The probability, per inheritance, that the inherited metabolism tape has a \
              copy of one of its segments, 1 to meta_seg_max bytes from a random place, \
              appended at its end, cut at meta_max_len. Drawn on a stream of its own. Read \
              only on a channel that grows.",
    },
    Field {
        name: "meta_del",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "The probability, per inheritance and after any duplication, that the \
              inherited metabolism tape loses a segment of 1 to meta_seg_max bytes from a \
              random place, never below meta_min_len. Read only on a channel that grows.",
    },
    Field {
        name: "meta_seg_max",
        kind: Kind::Integer {
            min: 1.0,
            max: META_LEN_MAX as f64,
        },
        doc: "The longest segment a duplication or deletion of a metabolism tape moves. \
              Read only on a channel that grows.",
    },
    Field {
        name: "meta_genes",
        kind: Kind::Integer {
            min: 0.0,
            max: META_LEN_MAX as f64,
        },
        doc: "The gene length G of the topless assay of a metabolism tape: the tape is cut \
              at offsets 0, G, 2G and so on, the last piece zero-padded to G, and each gene \
              is run alone on a buffer of 2G bytes with the inputs at its end, under the \
              assay's own emit and step budgets; the tape computes the union of its genes' \
              classes. No gene can read or undo another's result. It applies wherever a \
              metabolism tape is assayed, the predation pass and the readings, and needs \
              tasks logic3 or logic4 and a task_reward of 0, so it is never paid. 0 runs \
              the tape whole.",
    },
    Field {
        name: "init",
        kind: Kind::Choice(&["random", "zero"]),
        doc: "Initial world state: uniformly random bytes, or all zero (the control).",
    },
    Field {
        name: "sample_every",
        kind: Kind::Integer {
            min: 1.0,
            max: 1_000_000.0,
        },
        doc: "Record the observables every this many epochs.",
    },
    Field {
        name: "top_k",
        kind: Kind::Integer {
            min: 1.0,
            max: 256.0,
        },
        doc: "How many of the most common tapes are put through the replicator test.",
    },
    Field {
        name: "snapshot_every",
        kind: Kind::Integer {
            min: 1.0,
            max: 1_000_000.0,
        },
        doc: "Write a full world snapshot every this many epochs.",
    },
];

#[derive(Debug, Clone, PartialEq)]
pub enum ParamError {
    OutOfRange {
        field: &'static str,
        value: f64,
        min: f64,
        max: f64,
    },
    NotFinite {
        field: &'static str,
    },
    /// A neighbourhood wider than the world wraps onto itself: the same cell would sit at
    /// two offsets (double weight) and self-exclusion stops being reliable.
    RadiusTooWide {
        radius: u32,
        width: u32,
        height: u32,
    },
    /// `ops` is not a legal instruction set; `reason` says which rule it broke.
    InvalidOps {
        ops: String,
        reason: &'static str,
    },
    /// A cap below the length every tape starts at is not a world the engine can build:
    /// the tapes would have to be born over the cap.
    MaxTapeLenBelowInitial {
        max_tape_len: u32,
        tape_len: u32,
    },
    /// A steal op with no stock to steal from moves nothing whatever its amount: the
    /// parameter would be silently inert, which is the one thing a parameter must never be.
    StealWithoutStock {
        steal_amount: u32,
    },
    /// A stock that cannot hold one epoch's influx is no stock: the surplus would be
    /// thrown away the moment it arrived, and the economy would be the per-epoch
    /// allowance `energy_per_epoch` already is.
    StockCapBelowInflux {
        energy_stock_cap: u32,
        energy_influx: u32,
    },
    /// The initiator pays out of a stock: with no influx there is none, and no cell could
    /// ever initiate.
    InitiatorWithoutStock,
    /// A stock capped below the price of one interaction can never pay it: no cell would
    /// ever initiate.
    InitiatorPriceAboveCap {
        energy_stock_cap: u32,
        max_steps: u32,
    },
    /// The per-epoch allowance bounds an interaction by both cells' purses, which is the
    /// pair rule the initiator rule replaces; the two together would charge the partner
    /// after all.
    InitiatorWithAllowance {
        energy_per_epoch: u32,
    },
    /// Life has no tapes to assay.
    TasksOnLife,
    /// A floor that is no rung of the chosen ladder pays nothing or everything by accident.
    TaskFloorNotARung {
        task_floor: String,
        tasks: Tasks,
    },
    /// A NAND semantics where `~` is never an instruction is silently inert.
    LogicNandWithoutLogic {
        tasks: Tasks,
    },
    /// A reward with no tasks to earn it by is silently inert.
    TaskRewardWithoutTasks {
        task_reward: u32,
    },
    /// The reward is paid into the stock: with no influx there is none.
    TaskRewardWithoutStock {
        task_reward: u32,
    },
    /// The metabolism tape is what the logic assay reads: on any other ladder, or none, it
    /// would be state nothing ever reads.
    MetaWithoutLogic {
        meta_len: u32,
        tasks: Tasks,
    },
    /// A metabolism-tape setting with no tape to apply it to is silently inert.
    MetaParamWithoutTape {
        field: &'static str,
    },
    /// A depth cap where no rung has a depth is silently inert.
    DepthCapWithoutDepth {
        task_depth_cap: u32,
        tasks: Tasks,
    },
    /// Predation reads the topless assay's classes off the metabolism tape and moves stock
    /// an initiator lives on: without any of those it reads or moves nothing it means to.
    PredationNeeds {
        needs: &'static str,
    },
    /// A run is either paid or predatory, never both, so the label of what it imports
    /// stays clean.
    PredationPaid {
        task_reward: u32,
    },
    /// A wider assay on a paid run, or one with no topless ladder, would change what is
    /// paid or read nothing.
    WideAssayOutsideUnpaidTopless {
        task_max_outputs: u32,
    },
    /// A metabolism channel whose cap sits below the length every tape starts at, or whose
    /// floor sits above it, is not a channel the engine can build.
    MetaBounds {
        meta_len: u32,
        meta_min_len: u32,
        meta_max_len: u32,
    },
    /// A variation operator of a channel that cannot grow is silently inert.
    MetaGrowthWithoutRoom {
        field: &'static str,
    },
    /// Genes split what the topless assay reads, and must never change what is paid.
    GenesNeeds {
        needs: &'static str,
    },
}

impl fmt::Display for ParamError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::OutOfRange {
                field,
                value,
                min,
                max,
            } => write!(f, "{field} is {value}, outside {min}..={max}"),
            Self::NotFinite { field } => write!(f, "{field} is not a finite number"),
            Self::RadiusTooWide {
                radius,
                width,
                height,
            } => write!(
                f,
                "radius is {radius}, too wide for a {width}x{height} world: \
                 the largest legal radius is {}",
                (width.min(height) - 1) / 2
            ),
            Self::InvalidOps { ops, reason } => write!(f, "ops is {ops:?}: {reason}"),
            Self::MaxTapeLenBelowInitial {
                max_tape_len,
                tape_len,
            } => write!(
                f,
                "max_tape_len is {max_tape_len}, below the tape_len of {tape_len}: \
                 0 turns growth off, and any cap must be at least the initial length"
            ),
            Self::StealWithoutStock { steal_amount } => write!(
                f,
                "steal_amount is {steal_amount} with no energy_influx: a steal op needs a \
                 stock to take energy out of"
            ),
            Self::StockCapBelowInflux {
                energy_stock_cap,
                energy_influx,
            } => write!(
                f,
                "energy_stock_cap is {energy_stock_cap}, below the energy_influx of \
                 {energy_influx}: a stock must hold at least one epoch's influx"
            ),
            Self::InitiatorWithoutStock => write!(
                f,
                "energy_payer is initiator with no energy_influx: the initiator pays out of \
                 a stock"
            ),
            Self::InitiatorPriceAboveCap {
                energy_stock_cap,
                max_steps,
            } => write!(
                f,
                "energy_payer is initiator with an energy_stock_cap of {energy_stock_cap}, \
                 below the max_steps of {max_steps}: no stock could ever pay for an \
                 interaction"
            ),
            Self::InitiatorWithAllowance { energy_per_epoch } => write!(
                f,
                "energy_payer is initiator with an energy_per_epoch of {energy_per_epoch}: \
                 the allowance charges both cells, which the initiator rule does not"
            ),
            Self::TasksOnLife => write!(
                f,
                "tasks is set on the life substrate: only soup tapes can be assayed"
            ),
            Self::TaskFloorNotARung { task_floor, tasks } => {
                let rungs = tasks.rungs();
                if rungs.is_empty() {
                    write!(
                        f,
                        "task_floor is {task_floor} with tasks off: there is no ladder to \
                         pay from it"
                    )
                } else {
                    write!(
                        f,
                        "task_floor is {task_floor}, which is no rung of the {} ladder: one of \
                         {}",
                        tasks.name(),
                        rungs.join(", ")
                    )
                }
            }
            Self::LogicNandWithoutLogic { tasks } => write!(
                f,
                "logic_nand is stack with tasks {}: ~ is an instruction only in the logic \
                 assay",
                tasks.name()
            ),
            Self::TaskRewardWithoutTasks { task_reward } => write!(
                f,
                "task_reward is {task_reward} with tasks off: there is nothing to earn it by"
            ),
            Self::TaskRewardWithoutStock { task_reward } => write!(
                f,
                "task_reward is {task_reward} with no energy_influx: the reward is paid \
                 into a stock"
            ),
            Self::MetaWithoutLogic { meta_len, tasks } => write!(
                f,
                "meta_len is {meta_len} with tasks {}: the metabolism tape is read by the \
                 logic assay alone, so it needs tasks logic, logic3 or logic4",
                tasks.name()
            ),
            Self::MetaParamWithoutTape { field } => write!(
                f,
                "{field} is set with meta_len 0: there is no metabolism tape to apply it to"
            ),
            Self::DepthCapWithoutDepth {
                task_depth_cap,
                tasks,
            } => write!(
                f,
                "task_depth_cap is {task_depth_cap} with tasks {}: only the logic3 and logic4 \
                 rungs are paid by depth",
                tasks.name()
            ),
            Self::PredationNeeds { needs } => write!(
                f,
                "predation is set without {needs}: the pass reads the logic3 or logic4 \
                 classes of metabolism tapes and moves the stock an initiator pays from"
            ),
            Self::PredationPaid { task_reward } => write!(
                f,
                "predation is set with a task_reward of {task_reward}: a run is either paid \
                 or predatory, never both"
            ),
            Self::WideAssayOutsideUnpaidTopless { task_max_outputs } => write!(
                f,
                "task_max_outputs is {task_max_outputs}: above {TASK_MAX_OUTPUTS} it needs \
                 tasks logic3 or logic4 and a task_reward of 0"
            ),
            Self::MetaBounds {
                meta_len,
                meta_min_len,
                meta_max_len,
            } => write!(
                f,
                "meta_len is {meta_len} with meta_min_len {meta_min_len} and meta_max_len \
                 {meta_max_len}: a tape starts at meta_len, so the cap may not sit below it \
                 (0 keeps the channel fixed) nor, on a channel that grows, the floor above it"
            ),
            Self::MetaGrowthWithoutRoom { field } => write!(
                f,
                "{field} is set on a metabolism channel that cannot grow: meta_max_len must \
                 be above meta_len for it to be read"
            ),
            Self::GenesNeeds { needs } => write!(
                f,
                "meta_genes is set without {needs}: genes split the logic3 or logic4 assay \
                 of an unpaid run's metabolism tapes"
            ),
        }
    }
}

impl std::error::Error for ParamError {}

impl Params {
    pub fn validate(&self) -> Result<(), ParamError> {
        // The only way a `Params` fails to serialise is a non-finite float.
        let value = serde_json::to_value(self).map_err(|_| ParamError::NotFinite {
            field: "mutation_rate",
        })?;
        for field in FIELDS {
            let (min, max) = match field.kind {
                Kind::Choice(_) | Kind::Subset(_) => continue,
                Kind::Integer { min, max } | Kind::Float { min, max } => (min, max),
            };
            let n = value[field.name]
                .as_f64()
                .ok_or(ParamError::NotFinite { field: field.name })?;
            if n < min || n > max {
                return Err(ParamError::OutOfRange {
                    field: field.name,
                    value: n,
                    min,
                    max,
                });
            }
        }
        OpSet::parse(&self.ops).map_err(|reason| ParamError::InvalidOps {
            ops: self.ops.clone(),
            reason,
        })?;
        if self.max_tape_len > 0 && self.max_tape_len < self.tape_len {
            return Err(ParamError::MaxTapeLenBelowInitial {
                max_tape_len: self.max_tape_len,
                tape_len: self.tape_len,
            });
        }
        if self.energy_influx > 0 && self.energy_stock_cap < self.energy_influx {
            return Err(ParamError::StockCapBelowInflux {
                energy_stock_cap: self.energy_stock_cap,
                energy_influx: self.energy_influx,
            });
        }
        if self.steal_amount > 0 && self.energy_influx == 0 {
            return Err(ParamError::StealWithoutStock {
                steal_amount: self.steal_amount,
            });
        }
        if self.energy_payer == EnergyPayer::Initiator {
            self.validate_initiator()?;
        }
        self.validate_tasks()?;
        self.validate_meta()?;
        self.validate_predation()?;
        if self.radius > 0 && 2 * self.radius + 1 > self.width.min(self.height) {
            return Err(ParamError::RadiusTooWide {
                radius: self.radius,
                width: self.width,
                height: self.height,
            });
        }
        Ok(())
    }

    fn validate_initiator(&self) -> Result<(), ParamError> {
        if self.energy_influx == 0 {
            return Err(ParamError::InitiatorWithoutStock);
        }
        if self.energy_stock_cap < self.max_steps {
            return Err(ParamError::InitiatorPriceAboveCap {
                energy_stock_cap: self.energy_stock_cap,
                max_steps: self.max_steps,
            });
        }
        if self.energy_per_epoch > 0 {
            return Err(ParamError::InitiatorWithAllowance {
                energy_per_epoch: self.energy_per_epoch,
            });
        }
        Ok(())
    }

    fn validate_tasks(&self) -> Result<(), ParamError> {
        if self.tasks != Tasks::Off && self.substrate == Substrate::Life {
            return Err(ParamError::TasksOnLife);
        }
        if self.task_reward > 0 && self.tasks == Tasks::Off {
            return Err(ParamError::TaskRewardWithoutTasks {
                task_reward: self.task_reward,
            });
        }
        if self.task_reward > 0 && self.energy_influx == 0 {
            return Err(ParamError::TaskRewardWithoutStock {
                task_reward: self.task_reward,
            });
        }
        let defaulted = self.task_floor == TASK_FLOORS[0];
        if !defaulted && !self.tasks.rungs().contains(&self.task_floor.as_str()) {
            return Err(ParamError::TaskFloorNotARung {
                task_floor: self.task_floor.clone(),
                tasks: self.tasks,
            });
        }
        if self.logic_nand != LogicNand::InPlace && !self.tasks.is_logic() {
            return Err(ParamError::LogicNandWithoutLogic { tasks: self.tasks });
        }
        if self.task_depth_cap > 0 && self.tasks.depth_inputs().is_none() {
            return Err(ParamError::DepthCapWithoutDepth {
                task_depth_cap: self.task_depth_cap,
                tasks: self.tasks,
            });
        }
        Ok(())
    }

    fn validate_predation(&self) -> Result<(), ParamError> {
        let unpaid_topless = self.tasks.depth_inputs().is_some() && self.task_reward == 0;
        if self.task_max_outputs as usize > TASK_MAX_OUTPUTS && !unpaid_topless {
            return Err(ParamError::WideAssayOutsideUnpaidTopless {
                task_max_outputs: self.task_max_outputs,
            });
        }
        if self.predation == Predation::Off {
            return Ok(());
        }
        let missing = [
            (self.meta_len == 0, "a metabolism tape (meta_len above 0)"),
            (
                self.energy_influx == 0,
                "an energy stock (energy_influx above 0)",
            ),
            (
                self.energy_payer != EnergyPayer::Initiator,
                "the initiator payer (energy_payer initiator)",
            ),
            (
                self.tasks.depth_inputs().is_none(),
                "a topless ladder (tasks logic3 or logic4)",
            ),
        ];
        if let Some((_, needs)) = missing.into_iter().find(|(missing, _)| *missing) {
            return Err(ParamError::PredationNeeds { needs });
        }
        if self.task_reward > 0 {
            return Err(ParamError::PredationPaid {
                task_reward: self.task_reward,
            });
        }
        Ok(())
    }

    fn validate_meta(&self) -> Result<(), ParamError> {
        if self.meta_len > 0 {
            if !self.tasks.is_logic() {
                return Err(ParamError::MetaWithoutLogic {
                    meta_len: self.meta_len,
                    tasks: self.tasks,
                });
            }
            self.validate_meta_channel()?;
            return self.validate_genes();
        }
        let defaults = Params::default();
        let stray = [
            ("meta_rate", self.meta_rate != defaults.meta_rate),
            ("meta_draw", self.meta_draw != defaults.meta_draw),
            ("meta_seed", self.meta_seed != defaults.meta_seed),
            ("meta_max_len", self.meta_max_len != defaults.meta_max_len),
            ("meta_min_len", self.meta_min_len != defaults.meta_min_len),
            ("meta_dup", self.meta_dup != defaults.meta_dup),
            ("meta_del", self.meta_del != defaults.meta_del),
            ("meta_seg_max", self.meta_seg_max != defaults.meta_seg_max),
            ("meta_genes", self.meta_genes != defaults.meta_genes),
        ];
        match stray.into_iter().find(|(_, set)| *set) {
            Some((field, _)) => Err(ParamError::MetaParamWithoutTape { field }),
            None => Ok(()),
        }
    }

    fn validate_meta_channel(&self) -> Result<(), ParamError> {
        let below_len = self.meta_max_len != 0 && self.meta_max_len < self.meta_len;
        if below_len || (self.meta_grows() && self.meta_min_len > self.meta_len) {
            return Err(ParamError::MetaBounds {
                meta_len: self.meta_len,
                meta_min_len: self.meta_min_len,
                meta_max_len: self.meta_max_len,
            });
        }
        if self.meta_grows() {
            return Ok(());
        }
        let defaults = Params::default();
        let inert = [
            ("meta_min_len", self.meta_min_len != defaults.meta_min_len),
            ("meta_dup", self.meta_dup != defaults.meta_dup),
            ("meta_del", self.meta_del != defaults.meta_del),
            ("meta_seg_max", self.meta_seg_max != defaults.meta_seg_max),
        ];
        match inert.into_iter().find(|(_, set)| *set) {
            Some((field, _)) => Err(ParamError::MetaGrowthWithoutRoom { field }),
            None => Ok(()),
        }
    }

    fn validate_genes(&self) -> Result<(), ParamError> {
        if self.meta_genes == 0 {
            return Ok(());
        }
        let missing = [
            (
                self.tasks.depth_inputs().is_none(),
                "a topless ladder (tasks logic3 or logic4)",
            ),
            (self.task_reward > 0, "an unpaid run (task_reward 0)"),
        ];
        match missing.into_iter().find(|(missing, _)| *missing) {
            Some((_, needs)) => Err(ParamError::GenesNeeds { needs }),
            None => Ok(()),
        }
    }

    /// A JSON description of every parameter — name, type, default, range and doc — for
    /// Rails to build forms and validations from (`runner schema`), plus the transition
    /// rule Rails needs to read a stored series the way the tracker read it live.
    pub fn schema_json() -> String {
        let defaults = serde_json::to_value(Params::default()).expect("Params always serialises");
        let fields: Vec<serde_json::Value> = FIELDS
            .iter()
            .map(|field| {
                let mut entry = serde_json::json!({
                    "name": field.name,
                    "default": defaults[field.name],
                    "doc": field.doc,
                });
                match field.kind {
                    Kind::Choice(values) => {
                        entry["type"] = serde_json::json!("enum");
                        entry["values"] = serde_json::json!(values);
                    }
                    Kind::Subset(values) => {
                        entry["type"] = serde_json::json!("subset");
                        entry["values"] = serde_json::json!(values);
                    }
                    Kind::Integer { min, max } => {
                        entry["type"] = serde_json::json!("integer");
                        entry["min"] = serde_json::json!(min as i64);
                        entry["max"] = serde_json::json!(max as i64);
                    }
                    Kind::Float { min, max } => {
                        entry["type"] = serde_json::json!("float");
                        entry["min"] = serde_json::json!(min);
                        entry["max"] = serde_json::json!(max);
                    }
                }
                entry
            })
            .collect();
        serde_json::to_string_pretty(&serde_json::json!({
            "fields": fields,
            "transition": {
                "threshold": TRANSITION_THRESHOLD,
                "hold_samples": TRANSITION_HOLD_SAMPLES,
                "max_op_density": TRANSITION_MAX_OP_DENSITY,
                "min_alphabet_size": TRANSITION_MIN_ALPHABET_SIZE,
                "relative_fraction": TRANSITION_RELATIVE_FRACTION,
                "baseline_epochs": TRANSITION_BASELINE_EPOCHS,
            },
            "self_replication": {
                "generations": SELF_REP_GENERATIONS,
                "trials": SELF_REP_TRIALS,
                "agreement": SELF_REP_AGREEMENT_NUMERATOR as f64
                    / SELF_REP_AGREEMENT_DENOMINATOR as f64,
                "sample_cells": SELF_REP_SAMPLE_CELLS,
            },
            "tasks": {
                "steps": TASK_STEPS,
                "cases": TASK_CASES,
                "max_outputs": TASK_MAX_OUTPUTS,
                "input_range": TASK_INPUT_RANGE,
                "case_draws": TASK_CASE_DRAWS,
                "emit": (crate::bff::EMIT as char).to_string(),
                "ladder": TASKS
                    .iter()
                    .map(|task| serde_json::json!({"name": task.name, "units": task.units}))
                    .collect::<Vec<_>>(),
                "logic": {
                    "nand": (crate::bff::NAND as char).to_string(),
                    "case_draws": LOGIC_CASE_DRAWS,
                    "first_deep": LOGIC_TASKS[FIRST_DEEP_TASK].name,
                    "ladder": LOGIC_TASKS
                        .iter()
                        .map(|task| serde_json::json!({
                            "name": task.name,
                            "units": task.units,
                            "nands": task.nands,
                        }))
                        .collect::<Vec<_>>(),
                },
                "topless": {
                    "case_draws": DEPTH_CASE_DRAWS,
                    "reads_per_row": READS_PER_ROW,
                    "cases": {
                        "logic3": Inputs::Three.cases(),
                        "logic4": Inputs::Four.cases(),
                    },
                    "depth_units": DEPTH_UNITS,
                    "depth_floor": DEPTH_FLOOR,
                },
            },
        }))
        .expect("schema always serialises")
    }

    /// The instruction set this run executes. Only call on validated params: an `ops`
    /// string that does not parse falls back to the whole instruction set.
    pub fn op_set(&self) -> OpSet {
        OpSet::parse(&self.ops).unwrap_or(OpSet::ALL)
    }

    /// The mutation rate the cell at `(x, y)` lives under: `mutation_rate` itself in a
    /// uniform world, and the rate scaled by where the cell sits in a structured one. A
    /// pure function of the parameters and the position — it draws nothing — so a run
    /// stays determined by `(params, seed)`.
    pub fn mutation_rate_at(&self, x: u32, y: u32) -> f64 {
        match self.structure {
            Structure::Uniform => self.mutation_rate,
            Structure::Gradient => self.scaled_rate(gradient_lean(x, self.width)),
            Structure::Patchwork => self.scaled_rate(patchwork_lean(x, y, self.width, self.height)),
        }
    }

    /// The rate a cell leaning `lean` off the world's own rate runs at, `lean` being -1 in
    /// the driest cell and +1 in the wettest.
    fn scaled_rate(&self, lean: f64) -> f64 {
        (self.mutation_rate * (1.0 + self.structure_amplitude * lean)).clamp(0.0, 1.0)
    }

    /// The longest a tape may be: `max_tape_len` where a cap is set, and the length every
    /// tape starts and stays at where none is.
    pub fn tape_cap(&self) -> u32 {
        if self.max_tape_len == 0 {
            self.tape_len
        } else {
            self.max_tape_len
        }
    }

    /// Whether this run's tapes may lengthen at all. A cap equal to `tape_len` is the
    /// fixed-length world of DESIGN §1.1, exactly as `max_tape_len` 0 is.
    pub fn grows(&self) -> bool {
        self.substrate == Substrate::Soup && self.tape_cap() > self.tape_len
    }

    /// Whether this run's cells hold an energy stock at all. The influx is the switch: a
    /// cap on its own stocks nothing, and life has no interactions to pay for.
    pub fn stocked(&self) -> bool {
        self.substrate == Substrate::Soup && self.energy_influx > 0
    }

    /// Whether this run's steal byte is an instruction at all. The amount is the switch,
    /// as the influx is the stock's: a steal that moves nothing is not an economy, and
    /// validation refuses an amount with no stock behind it.
    pub fn steals(&self) -> bool {
        self.stocked() && self.steal_amount > 0
    }

    /// Whether this run pays for tasks at all. The reward is the switch: at 0 no assay
    /// runs, so a run with tasks on and no reward is byte for byte the run with tasks off.
    pub fn rewards_tasks(&self) -> bool {
        self.stocked() && self.tasks != Tasks::Off && self.task_reward > 0
    }

    /// Whether this run's cells carry a metabolism tape at all. The length is the switch:
    /// at 0 none is allocated, drawn, inherited or snapshotted.
    pub fn carries_meta(&self) -> bool {
        self.substrate == Substrate::Soup && self.meta_len > 0
    }

    /// The longest a metabolism tape of this run may be: `meta_max_len` where it is set,
    /// and the length every tape starts and stays at where it is not.
    pub fn meta_cap(&self) -> u32 {
        match self.meta_max_len {
            0 => self.meta_len,
            cap => cap,
        }
    }

    /// Whether this run's metabolism tapes may change length at all. A cap equal to
    /// `meta_len` is the fixed channel, exactly as `meta_max_len` 0 is.
    pub fn meta_grows(&self) -> bool {
        self.carries_meta() && self.meta_cap() > self.meta_len
    }

    /// The gene length the topless assay splits a metabolism tape into, `None` where it
    /// runs the tape whole.
    pub fn gene_len(&self) -> Option<usize> {
        (self.carries_meta() && self.meta_genes > 0).then_some(self.meta_genes as usize)
    }

    /// Whether this run's predation pass runs at all: a relation chosen and a transfer to
    /// move, on a soup whose cells hold a stock and a metabolism tape and sit on a topless
    /// ladder. At `off` or a transfer of 0 nothing is drawn, read or moved.
    pub fn predates(&self) -> bool {
        self.predation != Predation::Off
            && self.predation_transfer > 0
            && self.stocked()
            && self.carries_meta()
            && self.tasks.depth_inputs().is_some()
    }

    /// The output slots the topless assay reads, never past `TASK_MAX_OUTPUTS_LIMIT`.
    pub fn assay_slots(&self) -> usize {
        (self.task_max_outputs as usize).clamp(TASK_MAX_OUTPUTS, TASK_MAX_OUTPUTS_LIMIT)
    }

    /// The depth the topless ladder pays a deeper rung as, `None` where it caps nothing.
    pub fn depth_cap(&self) -> Option<u32> {
        (self.task_depth_cap > 0).then_some(self.task_depth_cap)
    }

    /// The index, on this run's ladder, of the lowest rung it pays: `task_floor`'s rung,
    /// and the first where it names none, which validation refuses.
    pub fn task_floor_rung(&self) -> usize {
        self.tasks
            .rungs()
            .iter()
            .position(|rung| *rung == self.task_floor)
            .unwrap_or(0)
    }

    /// Bytes of state one cell's slot holds: the tape cap in the soup, one byte in life.
    /// A soup cell whose tapes can grow fills its slot only up to its live length.
    pub fn stride(&self) -> usize {
        match self.substrate {
            Substrate::Soup => self.tape_cap() as usize,
            Substrate::Life => 1,
        }
    }

    pub fn cell_count(&self) -> usize {
        self.width as usize * self.height as usize
    }

    /// How many lineage tags a world of these params holds: one per cell in the soup,
    /// none in life, which carries no ancestry.
    pub fn lineage_count(&self) -> usize {
        match self.substrate {
            Substrate::Soup => self.cell_count(),
            Substrate::Life => 0,
        }
    }
}

/// A triangle wave across the columns: -1 at column 0, +1 half a world east, -1 again as
/// it comes back round.
fn gradient_lean(x: u32, width: u32) -> f64 {
    let across = f64::from(x) / f64::from(width);
    1.0 - 2.0 * (2.0 * across - 1.0).abs()
}

/// Quadrants alternating dry and wet. An odd-sided world has no exact half, and the
/// middle column or row falls with the first half of its axis.
fn patchwork_lean(x: u32, y: u32, width: u32, height: u32) -> f64 {
    if (2 * x < width) == (2 * y < height) {
        -1.0
    } else {
        1.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_validate() {
        assert_eq!(Params::default().validate(), Ok(()));
    }

    #[test]
    fn rejects_out_of_range_values() {
        let params = Params {
            width: 2,
            ..Params::default()
        };
        assert!(matches!(
            params.validate(),
            Err(ParamError::OutOfRange { field: "width", .. })
        ));

        let params = Params {
            mutation_rate: 1.5,
            ..Params::default()
        };
        assert!(matches!(
            params.validate(),
            Err(ParamError::OutOfRange {
                field: "mutation_rate",
                ..
            })
        ));
    }

    #[test]
    fn rejects_a_neighbourhood_wider_than_the_world() {
        let too_wide = Params {
            width: 8,
            height: 8,
            radius: 4,
            ..Params::default()
        };
        assert_eq!(
            too_wide.validate(),
            Err(ParamError::RadiusTooWide {
                radius: 4,
                width: 8,
                height: 8
            })
        );
        assert!(too_wide.validate().unwrap_err().to_string().contains("3"));

        assert_eq!(
            Params {
                radius: 3,
                ..too_wide.clone()
            }
            .validate(),
            Ok(())
        );
        assert_eq!(
            Params {
                width: 32,
                height: 32,
                ..too_wide
            }
            .validate(),
            Ok(())
        );
    }

    #[test]
    fn accepts_a_well_mixed_radius_at_every_size() {
        for side in [4, 8, 128, 1024] {
            let params = Params {
                width: side,
                height: side,
                radius: 0,
                ..Params::default()
            };
            assert_eq!(params.validate(), Ok(()), "{side}x{side}");
        }
    }

    #[test]
    fn rejects_an_instruction_set_that_is_not_a_subset_named_once_each() {
        for ops in ["", "++", "+a", "<>{}+-.,[]<"] {
            let params = Params {
                ops: ops.to_string(),
                ..Params::default()
            };
            assert!(
                matches!(params.validate(), Err(ParamError::InvalidOps { .. })),
                "{ops:?}"
            );
        }

        let ablated = Params {
            ops: "<>{}+-.".to_string(),
            ..Params::default()
        };
        assert_eq!(ablated.validate(), Ok(()));
        assert!(!ablated.op_set().enables(b','));
    }

    #[test]
    fn the_default_instruction_set_is_the_whole_one() {
        assert_eq!(Params::default().ops, "<>{}+-.,[]");
        assert_eq!(Params::default().op_set(), OpSet::ALL);
    }

    #[test]
    fn the_instruction_cost_is_off_by_default_and_bounded_when_on() {
        assert_eq!(Params::default().energy_per_epoch, 0);

        let costly = Params {
            energy_per_epoch: 4096,
            ..Params::default()
        };
        assert_eq!(costly.validate(), Ok(()));

        let beyond = Params {
            energy_per_epoch: 1_048_577,
            ..Params::default()
        };
        assert!(matches!(
            beyond.validate(),
            Err(ParamError::OutOfRange {
                field: "energy_per_epoch",
                ..
            })
        ));
    }

    #[test]
    fn the_energy_stock_is_off_by_default_and_the_influx_is_its_switch() {
        assert_eq!(Params::default().energy_influx, 0);
        assert_eq!(Params::default().energy_stock_cap, 0);
        assert!(!Params::default().stocked());

        let capped_only = Params {
            energy_stock_cap: 4096,
            ..Params::default()
        };
        assert_eq!(capped_only.validate(), Ok(()));
        assert!(!capped_only.stocked());

        let stocked = Params {
            energy_influx: 64,
            energy_stock_cap: 4096,
            ..Params::default()
        };
        assert_eq!(stocked.validate(), Ok(()));
        assert!(stocked.stocked());

        assert!(!Params {
            substrate: Substrate::Life,
            ..stocked
        }
        .stocked());
    }

    #[test]
    fn rejects_a_stock_cap_below_one_epochs_influx() {
        let params = Params {
            energy_influx: 64,
            energy_stock_cap: 32,
            ..Params::default()
        };
        assert_eq!(
            params.validate(),
            Err(ParamError::StockCapBelowInflux {
                energy_stock_cap: 32,
                energy_influx: 64
            })
        );
        assert!(params.validate().unwrap_err().to_string().contains("64"));

        let beyond = Params {
            energy_influx: 1_048_577,
            energy_stock_cap: 1_048_576,
            ..Params::default()
        };
        assert!(matches!(
            beyond.validate(),
            Err(ParamError::OutOfRange {
                field: "energy_influx",
                ..
            })
        ));
    }

    #[test]
    fn tapes_cannot_grow_by_default_and_a_cap_at_the_initial_length_is_the_same_world() {
        assert_eq!(Params::default().max_tape_len, 0);
        assert!(!Params::default().grows());
        assert_eq!(Params::default().tape_cap(), Params::default().tape_len);

        let at_the_initial_length = Params {
            max_tape_len: Params::default().tape_len,
            ..Params::default()
        };
        assert_eq!(at_the_initial_length.validate(), Ok(()));
        assert!(!at_the_initial_length.grows());
        assert_eq!(at_the_initial_length.stride(), Params::default().stride());

        let roomy = Params {
            max_tape_len: 256,
            ..Params::default()
        };
        assert_eq!(roomy.validate(), Ok(()));
        assert!(roomy.grows());
        assert_eq!(roomy.tape_cap(), 256);
        assert_eq!(roomy.stride(), 256);
    }

    #[test]
    fn rejects_a_cap_below_the_length_a_tape_starts_at() {
        let params = Params {
            tape_len: 64,
            max_tape_len: 32,
            ..Params::default()
        };
        assert_eq!(
            params.validate(),
            Err(ParamError::MaxTapeLenBelowInitial {
                max_tape_len: 32,
                tape_len: 64
            })
        );
        assert!(params.validate().unwrap_err().to_string().contains("64"));

        let beyond = Params {
            max_tape_len: 2048,
            ..Params::default()
        };
        assert!(matches!(
            beyond.validate(),
            Err(ParamError::OutOfRange {
                field: "max_tape_len",
                ..
            })
        ));
    }

    /// Life cells are single bits, and a cap over a tape length the substrate never reads
    /// must not widen them.
    #[test]
    fn a_life_cell_is_one_byte_whatever_the_cap_says() {
        let params = Params {
            substrate: Substrate::Life,
            max_tape_len: 256,
            ..Params::default()
        };
        assert_eq!(params.stride(), 1);
        assert!(!params.grows());
    }

    #[test]
    fn the_world_is_uniform_by_default_and_its_amplitude_is_bounded() {
        assert_eq!(Params::default().structure, Structure::Uniform);

        let structured = Params {
            structure: Structure::Patchwork,
            structure_amplitude: 1.0,
            ..Params::default()
        };
        assert_eq!(structured.validate(), Ok(()));

        let beyond = Params {
            structure_amplitude: 1.5,
            ..Params::default()
        };
        assert!(matches!(
            beyond.validate(),
            Err(ParamError::OutOfRange {
                field: "structure_amplitude",
                ..
            })
        ));
    }

    #[test]
    fn a_uniform_world_runs_one_rate_in_every_cell() {
        let params = Params {
            mutation_rate: 0.25,
            structure_amplitude: 1.0,
            ..Params::default()
        };
        for (x, y) in [(0, 0), (63, 12), (127, 127)] {
            assert_eq!(params.mutation_rate_at(x, y), 0.25, "at ({x}, {y})");
        }
    }

    #[test]
    fn a_gradient_runs_by_column_driest_at_the_first_and_meeting_itself_across_the_wrap() {
        let params = Params {
            width: 128,
            height: 128,
            mutation_rate: 0.2,
            structure: Structure::Gradient,
            structure_amplitude: 0.5,
            ..Params::default()
        };
        assert!((params.mutation_rate_at(0, 0) - 0.1).abs() < 1e-12);
        assert!((params.mutation_rate_at(64, 0) - 0.3).abs() < 1e-12);
        assert!((params.mutation_rate_at(32, 0) - 0.2).abs() < 1e-12);
        assert_eq!(
            params.mutation_rate_at(64, 0),
            params.mutation_rate_at(64, 99)
        );
        assert!((params.mutation_rate_at(127, 0) - params.mutation_rate_at(1, 0)).abs() < 1e-12);
    }

    #[test]
    fn a_patchwork_alternates_dry_and_wet_quadrants() {
        let params = Params {
            width: 8,
            height: 8,
            mutation_rate: 0.2,
            structure: Structure::Patchwork,
            structure_amplitude: 0.5,
            ..Params::default()
        };
        assert!((params.mutation_rate_at(1, 1) - 0.1).abs() < 1e-12);
        assert!((params.mutation_rate_at(5, 5) - 0.1).abs() < 1e-12);
        assert!((params.mutation_rate_at(5, 1) - 0.3).abs() < 1e-12);
        assert!((params.mutation_rate_at(1, 5) - 0.3).abs() < 1e-12);
    }

    #[test]
    fn a_patchwork_puts_the_middle_of_an_odd_world_with_the_first_half_of_its_axis() {
        let params = Params {
            width: 9,
            height: 9,
            mutation_rate: 0.2,
            structure: Structure::Patchwork,
            structure_amplitude: 0.5,
            ..Params::default()
        };
        assert!((params.mutation_rate_at(4, 4) - 0.1).abs() < 1e-12);
        assert!((params.mutation_rate_at(5, 4) - 0.3).abs() < 1e-12);
        assert!((params.mutation_rate_at(4, 5) - 0.3).abs() < 1e-12);
        assert!((params.mutation_rate_at(5, 5) - 0.1).abs() < 1e-12);
    }

    /// An amplitude deep enough to take a cell past a probability cannot: a rate is one.
    #[test]
    fn a_structured_rate_stays_a_probability() {
        let params = Params {
            width: 8,
            height: 8,
            mutation_rate: 0.9,
            structure: Structure::Patchwork,
            structure_amplitude: 1.0,
            ..Params::default()
        };
        assert_eq!(params.mutation_rate_at(5, 1), 1.0);
        assert_eq!(params.mutation_rate_at(1, 1), 0.0);
    }

    #[test]
    fn rejects_non_finite_mutation_rate() {
        let params = Params {
            mutation_rate: f64::NAN,
            ..Params::default()
        };
        assert_eq!(
            params.validate(),
            Err(ParamError::NotFinite {
                field: "mutation_rate"
            })
        );
    }

    #[test]
    fn schema_describes_every_field_with_its_default() {
        let schema: serde_json::Value = serde_json::from_str(&Params::schema_json()).unwrap();
        let fields = schema["fields"].as_array().unwrap();
        assert_eq!(fields.len(), 45);

        let width = fields.iter().find(|f| f["name"] == "width").unwrap();
        assert_eq!(width["type"], "integer");
        assert_eq!(width["default"], 128);
        assert_eq!(width["min"], 4);
        assert_eq!(width["max"], 1024);

        let ops = fields.iter().find(|f| f["name"] == "ops").unwrap();
        assert_eq!(ops["type"], "subset");
        assert_eq!(ops["default"], "<>{}+-.,[]");
        assert_eq!(ops["values"].as_array().unwrap().len(), 10);

        let energy = fields
            .iter()
            .find(|f| f["name"] == "energy_per_epoch")
            .unwrap();
        assert_eq!(energy["type"], "integer");
        assert_eq!(energy["default"], 0);
        assert_eq!(energy["min"], 0);

        for name in ["energy_influx", "energy_stock_cap"] {
            let stock = fields.iter().find(|f| f["name"] == name).unwrap();
            assert_eq!(stock["type"], "integer", "{name}");
            assert_eq!(stock["default"], 0, "{name}");
            assert_eq!(stock["min"], 0, "{name}");
            assert_eq!(stock["max"], 1_048_576, "{name}");
        }

        let cap = fields.iter().find(|f| f["name"] == "max_tape_len").unwrap();
        assert_eq!(cap["type"], "integer");
        assert_eq!(cap["default"], 0);
        assert_eq!(cap["min"], 0);
        assert_eq!(cap["max"], 1024);

        let structure = fields.iter().find(|f| f["name"] == "structure").unwrap();
        assert_eq!(structure["type"], "enum");
        assert_eq!(structure["default"], "uniform");
        assert_eq!(
            structure["values"],
            serde_json::json!(["uniform", "gradient", "patchwork"])
        );

        let interaction = fields.iter().find(|f| f["name"] == "interaction").unwrap();
        assert_eq!(interaction["type"], "enum");
        assert_eq!(interaction["default"], "concat");
        assert_eq!(interaction["values"], serde_json::json!(["concat", "host"]));

        let payer = fields.iter().find(|f| f["name"] == "energy_payer").unwrap();
        assert_eq!(payer["type"], "enum");
        assert_eq!(payer["default"], "pair");
        assert_eq!(payer["values"], serde_json::json!(["pair", "initiator"]));

        let tasks = fields.iter().find(|f| f["name"] == "tasks").unwrap();
        assert_eq!(tasks["type"], "enum");
        assert_eq!(tasks["default"], "off");
        assert_eq!(
            tasks["values"],
            serde_json::json!(["off", "arith", "logic", "logic3", "logic4"])
        );
        let floor = fields.iter().find(|f| f["name"] == "task_floor").unwrap();
        assert_eq!(floor["type"], "enum");
        assert_eq!(floor["default"], "echo");
        assert_eq!(floor["values"], serde_json::json!(TASK_FLOORS));
        let nand = fields.iter().find(|f| f["name"] == "logic_nand").unwrap();
        assert_eq!(nand["type"], "enum");
        assert_eq!(nand["default"], "in_place");
        assert_eq!(nand["values"], serde_json::json!(["in_place", "stack"]));
        let every = fields.iter().find(|f| f["name"] == "task_every").unwrap();
        assert_eq!(
            (every["default"].as_i64(), every["min"].as_i64()),
            (Some(8), Some(1))
        );
        let reward = fields.iter().find(|f| f["name"] == "task_reward").unwrap();
        assert_eq!(
            (reward["default"].as_i64(), reward["min"].as_i64()),
            (Some(0), Some(0))
        );

        let rule = fields.iter().find(|f| f["name"] == "lineage_rule").unwrap();
        assert_eq!(rule["type"], "enum");
        assert_eq!(rule["default"], "aligned");
        assert_eq!(rule["values"], serde_json::json!(["aligned", "oriented"]));

        let substrate = fields.iter().find(|f| f["name"] == "substrate").unwrap();
        assert_eq!(substrate["type"], "enum");
        assert_eq!(substrate["values"], serde_json::json!(["soup", "life"]));
    }

    #[test]
    fn schema_carries_the_transition_rule_the_engine_measures_by() {
        let schema: serde_json::Value = serde_json::from_str(&Params::schema_json()).unwrap();
        let transition = &schema["transition"];
        assert_eq!(transition["threshold"], TRANSITION_THRESHOLD);
        assert_eq!(transition["hold_samples"], TRANSITION_HOLD_SAMPLES);
        assert_eq!(transition["threshold"], 0.6);
        assert_eq!(transition["hold_samples"], 3);
        assert_eq!(transition["max_op_density"], TRANSITION_MAX_OP_DENSITY);
        assert_eq!(
            transition["min_alphabet_size"],
            TRANSITION_MIN_ALPHABET_SIZE
        );
        assert_eq!(
            transition["relative_fraction"],
            TRANSITION_RELATIVE_FRACTION
        );
        assert_eq!(transition["baseline_epochs"], TRANSITION_BASELINE_EPOCHS);
    }

    #[test]
    fn schema_carries_the_orientation_aware_detector_the_census_companions_read_by() {
        let schema: serde_json::Value = serde_json::from_str(&Params::schema_json()).unwrap();
        assert_eq!(
            schema["self_replication"],
            serde_json::json!({
                "generations": 5,
                "trials": 5,
                "agreement": 0.75,
                "sample_cells": 256,
            })
        );
    }

    #[test]
    fn only_the_soup_counts_lineages() {
        let soup = Params {
            width: 8,
            height: 4,
            ..Params::default()
        };
        assert_eq!(soup.lineage_count(), soup.cell_count());
        assert_eq!(
            Params {
                substrate: Substrate::Life,
                ..soup
            }
            .lineage_count(),
            0
        );
    }

    #[test]
    fn json_round_trips_and_rejects_unknown_fields() {
        let json = serde_json::to_string(&Params::default()).unwrap();
        assert_eq!(
            serde_json::from_str::<Params>(&json).unwrap(),
            Params::default()
        );
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"width": 32}"#).unwrap(),
            Params {
                width: 32,
                ..Params::default()
            }
        );
        assert!(serde_json::from_str::<Params>(r#"{"nope": 1}"#).is_err());
    }

    /// A shape the engine does not have is refused where the run is loaded, not silently
    /// read as a uniform world.
    #[test]
    fn json_rejects_a_structure_the_engine_has_no_shape_for() {
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"structure": "patchwork"}"#).unwrap(),
            Params {
                structure: Structure::Patchwork,
                ..Params::default()
            }
        );
        assert!(serde_json::from_str::<Params>(r#"{"structure": "swirl"}"#).is_err());
    }

    /// The asymmetric execution mode of §1.1, off by default: an interaction runs the
    /// whole concatenation unless the run asks for a host.
    #[test]
    fn an_interaction_runs_the_whole_concatenation_by_default() {
        assert_eq!(Params::default().interaction, Interaction::Concat);
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"interaction": "host"}"#).unwrap(),
            Params {
                interaction: Interaction::Host,
                ..Params::default()
            }
        );
        assert!(serde_json::from_str::<Params>(r#"{"interaction": "duel"}"#).is_err());
    }

    /// The lineage rule of §1.2 is the aligned one unless a run asks for the other.
    #[test]
    fn a_lineage_tag_follows_aligned_descent_by_default() {
        assert_eq!(Params::default().lineage_rule, LineageRule::Aligned);
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"lineage_rule": "oriented"}"#).unwrap(),
            Params {
                lineage_rule: LineageRule::Oriented,
                ..Params::default()
            }
        );
        assert!(serde_json::from_str::<Params>(r#"{"lineage_rule": "sideways"}"#).is_err());
    }

    fn initiator_params() -> Params {
        Params {
            max_steps: 64,
            energy_influx: 8,
            energy_stock_cap: 64,
            energy_payer: EnergyPayer::Initiator,
            ..Params::default()
        }
    }

    /// Both cells pay unless a run asks for the initiator to.
    #[test]
    fn both_cells_pay_for_an_interaction_by_default() {
        assert_eq!(Params::default().energy_payer, EnergyPayer::Pair);
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"energy_payer": "initiator"}"#).unwrap(),
            Params {
                energy_payer: EnergyPayer::Initiator,
                ..Params::default()
            }
        );
        assert!(serde_json::from_str::<Params>(r#"{"energy_payer": "partner"}"#).is_err());
        assert_eq!(initiator_params().validate(), Ok(()));
    }

    #[test]
    fn rejects_an_initiator_with_no_stock_to_pay_from() {
        let params = Params {
            energy_influx: 0,
            ..initiator_params()
        };
        assert_eq!(params.validate(), Err(ParamError::InitiatorWithoutStock));
        assert!(params
            .validate()
            .unwrap_err()
            .to_string()
            .contains("energy_influx"));
    }

    #[test]
    fn rejects_an_initiator_whose_stock_can_never_hold_the_price() {
        let params = Params {
            energy_stock_cap: 63,
            ..initiator_params()
        };
        assert_eq!(
            params.validate(),
            Err(ParamError::InitiatorPriceAboveCap {
                energy_stock_cap: 63,
                max_steps: 64
            })
        );
        assert!(params.validate().unwrap_err().to_string().contains("63"));
    }

    #[test]
    fn rejects_an_initiator_beside_the_per_epoch_allowance() {
        let params = Params {
            energy_per_epoch: 32,
            ..initiator_params()
        };
        assert_eq!(
            params.validate(),
            Err(ParamError::InitiatorWithAllowance {
                energy_per_epoch: 32
            })
        );
    }

    /// The refusals are the initiator's alone: the pair rule keeps every combination it
    /// accepted before the parameter existed.
    #[test]
    fn the_pair_rule_accepts_what_the_initiator_refuses() {
        let pair = Params {
            energy_payer: EnergyPayer::Pair,
            energy_stock_cap: 32,
            energy_per_epoch: 32,
            ..initiator_params()
        };
        assert_eq!(pair.validate(), Ok(()));
    }

    #[test]
    fn schema_carries_the_task_assay_and_its_ladder() {
        let schema: serde_json::Value = serde_json::from_str(&Params::schema_json()).unwrap();
        assert_eq!(
            schema["tasks"],
            serde_json::json!({
                "steps": 4096,
                "cases": 3,
                "max_outputs": 4,
                "input_range": 16,
                "case_draws": 1024,
                "emit": "!",
                "ladder": [
                    {"name": "echo", "units": 1},
                    {"name": "inc", "units": 2},
                    {"name": "dec", "units": 2},
                    {"name": "add", "units": 4},
                    {"name": "sub", "units": 4},
                    {"name": "not", "units": 8},
                    {"name": "double", "units": 8},
                    {"name": "mul", "units": 16},
                ],
                "logic": {
                    "nand": "~",
                    "case_draws": 1024,
                    "first_deep": "xor",
                    "ladder": [
                        {"name": "echo", "units": 1, "nands": 0},
                        {"name": "not", "units": 1, "nands": 1},
                        {"name": "nand", "units": 1, "nands": 1},
                        {"name": "and", "units": 2, "nands": 2},
                        {"name": "orn", "units": 2, "nands": 2},
                        {"name": "or", "units": 4, "nands": 3},
                        {"name": "andn", "units": 4, "nands": 3},
                        {"name": "nor", "units": 8, "nands": 4},
                        {"name": "xor", "units": 8, "nands": 4},
                        {"name": "equ", "units": 16, "nands": 5},
                    ],
                },
                "topless": {
                    "case_draws": 1024,
                    "reads_per_row": 3,
                    "cases": {"logic3": 3, "logic4": 6},
                    "depth_units": [1, 1, 2, 3, 4, 6, 8, 11, 16, 23, 32, 45, 64, 91],
                    "depth_floor": 13,
                },
            })
        );
    }

    fn rewarded_params() -> Params {
        Params {
            energy_influx: 8,
            energy_stock_cap: 64,
            tasks: Tasks::Arith,
            task_reward: 2,
            ..Params::default()
        }
    }

    /// No task is assayed or paid unless a run asks for both.
    #[test]
    fn tasks_are_off_and_unpaid_by_default() {
        let params = Params::default();
        assert_eq!(
            (params.tasks, params.task_every, params.task_reward),
            (Tasks::Off, 8, 0)
        );
        assert!(!params.rewards_tasks());
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"tasks": "arith"}"#).unwrap(),
            Params {
                tasks: Tasks::Arith,
                ..Params::default()
            }
        );
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"tasks": "logic"}"#).unwrap(),
            Params {
                tasks: Tasks::Logic,
                ..Params::default()
            }
        );
        assert!(serde_json::from_str::<Params>(r#"{"tasks": "bool"}"#).is_err());
        assert_eq!(params.task_floor, "echo");
        assert_eq!(params.task_floor_rung(), 0);
        assert_eq!(rewarded_params().validate(), Ok(()));
        assert!(rewarded_params().rewards_tasks());
    }

    /// Tasks with no reward are the control arm, and need no economy at all; under either
    /// payer a reward is accepted, since the pair rule is a legitimate control too.
    #[test]
    fn tasks_need_a_stock_only_once_they_pay() {
        let control = Params {
            energy_influx: 0,
            energy_stock_cap: 0,
            task_reward: 0,
            ..rewarded_params()
        };
        assert_eq!(control.validate(), Ok(()));
        assert!(!control.rewards_tasks());
        let initiator = Params {
            max_steps: 64,
            energy_payer: EnergyPayer::Initiator,
            ..rewarded_params()
        };
        assert_eq!(initiator.validate(), Ok(()));
    }

    #[test]
    fn rejects_a_task_reward_with_no_stock_to_pay_into() {
        let params = Params {
            energy_influx: 0,
            ..rewarded_params()
        };
        assert_eq!(
            params.validate(),
            Err(ParamError::TaskRewardWithoutStock { task_reward: 2 })
        );
        assert!(params
            .validate()
            .unwrap_err()
            .to_string()
            .contains("energy_influx"));
    }

    #[test]
    fn rejects_a_task_reward_with_no_tasks_to_earn_it() {
        let params = Params {
            tasks: Tasks::Off,
            ..rewarded_params()
        };
        assert_eq!(
            params.validate(),
            Err(ParamError::TaskRewardWithoutTasks { task_reward: 2 })
        );
    }

    #[test]
    fn rejects_tasks_on_life() {
        let params = Params {
            substrate: Substrate::Life,
            tasks: Tasks::Arith,
            ..Params::default()
        };
        assert_eq!(params.validate(), Err(ParamError::TasksOnLife));
        assert!(Params {
            substrate: Substrate::Life,
            ..Params::default()
        }
        .validate()
        .is_ok());
    }

    #[test]
    fn rejects_an_assay_every_zero_epochs() {
        let params = Params {
            task_every: 0,
            ..rewarded_params()
        };
        assert!(matches!(
            params.validate(),
            Err(ParamError::OutOfRange {
                field: "task_every",
                ..
            })
        ));
    }

    /// Every rung of both ladders is a floor some run may name, each named once, and both
    /// ladders begin at the default.
    #[test]
    fn the_task_floors_are_the_rungs_of_both_ladders() {
        let mut both = Tasks::Arith.rungs();
        for rung in Tasks::Logic.rungs() {
            if !both.contains(&rung) {
                both.push(rung);
            }
        }
        assert_eq!(TASK_FLOORS, both.as_slice());
        assert_eq!(Tasks::Arith.rungs()[0], TASK_FLOORS[0]);
        assert_eq!(Tasks::Logic.rungs()[0], TASK_FLOORS[0]);
        assert!(Tasks::Off.rungs().is_empty());
    }

    /// A floor names a rung of the run's own ladder, and reads as that rung's index; the
    /// deep-only arm's `xor` is the logic ladder's first deep rung.
    #[test]
    fn a_task_floor_is_a_rung_of_the_chosen_ladder() {
        let floored = |tasks, task_floor: &str| Params {
            tasks,
            task_floor: task_floor.to_string(),
            ..rewarded_params()
        };
        let deep_only = floored(Tasks::Logic, "xor");
        assert_eq!(deep_only.validate(), Ok(()));
        assert_eq!(deep_only.task_floor_rung(), crate::logic::FIRST_DEEP_TASK);
        let arith = floored(Tasks::Arith, "add");
        assert_eq!(arith.validate(), Ok(()));
        assert_eq!(arith.task_floor_rung(), 3);
        assert_eq!(floored(Tasks::Logic, "not").task_floor_rung(), 1);
        assert_eq!(floored(Tasks::Arith, "not").task_floor_rung(), 5);

        for (tasks, task_floor) in [
            (Tasks::Logic, "mul"),
            (Tasks::Arith, "xor"),
            (Tasks::Logic, "anything"),
        ] {
            let params = floored(tasks, task_floor);
            assert_eq!(
                params.validate(),
                Err(ParamError::TaskFloorNotARung {
                    task_floor: task_floor.to_string(),
                    tasks,
                })
            );
        }
        assert_eq!(
            floored(Tasks::Arith, "xor")
                .validate()
                .unwrap_err()
                .to_string(),
            "task_floor is xor, which is no rung of the arith ladder: one of echo, inc, dec, \
             add, sub, not, double, mul"
        );
    }

    /// With tasks off there is no ladder, so only the default floor is accepted.
    #[test]
    fn rejects_a_task_floor_with_tasks_off() {
        let params = Params {
            task_floor: "xor".to_string(),
            ..Params::default()
        };
        assert_eq!(
            params.validate(),
            Err(ParamError::TaskFloorNotARung {
                task_floor: "xor".to_string(),
                tasks: Tasks::Off,
            })
        );
        assert_eq!(
            params.validate().unwrap_err().to_string(),
            "task_floor is xor with tasks off: there is no ladder to pay from it"
        );
        assert_eq!(Params::default().validate(), Ok(()));
    }

    fn meta_params() -> Params {
        Params {
            tasks: Tasks::Logic,
            meta_len: 32,
            meta_draw: MetaDraw::Isa,
            meta_seed: MetaSeed::OwnTape,
            ..rewarded_params()
        }
    }

    /// The metabolism tape is off by default, and every setting of it is read by name.
    #[test]
    fn the_metabolism_tape_is_off_by_default() {
        let params = Params::default();
        assert_eq!(params.meta_len, 0);
        assert!(!params.carries_meta());
        assert_eq!(
            (params.meta_rate, params.meta_draw, params.meta_seed),
            (32.0 / 8192.0, MetaDraw::Uniform, MetaSeed::Zeros)
        );
        assert_eq!(
            serde_json::from_str::<Params>(
                r#"{"tasks": "logic", "meta_len": 32, "meta_draw": "isa", "meta_seed": "own_tape"}"#
            )
            .unwrap(),
            Params {
                tasks: Tasks::Logic,
                meta_len: 32,
                meta_draw: MetaDraw::Isa,
                meta_seed: MetaSeed::OwnTape,
                ..Params::default()
            }
        );
        assert!(serde_json::from_str::<Params>(r#"{"meta_seed": "ownTape"}"#).is_err());
        assert_eq!(meta_params().validate(), Ok(()));
        assert!(meta_params().carries_meta());
    }

    /// Only the logic assay reads the tape, so it needs that ladder, paid or not.
    #[test]
    fn rejects_a_metabolism_tape_off_the_logic_ladder() {
        for tasks in [Tasks::Off, Tasks::Arith] {
            let params = Params {
                tasks,
                task_reward: 0,
                ..meta_params()
            };
            assert_eq!(
                params.validate(),
                Err(ParamError::MetaWithoutLogic {
                    meta_len: 32,
                    tasks
                })
            );
        }
        let unpaid = Params {
            task_reward: 0,
            energy_influx: 0,
            energy_stock_cap: 0,
            ..meta_params()
        };
        assert_eq!(unpaid.validate(), Ok(()));
    }

    /// With no tape, any of its settings away from the default would be silently inert.
    #[test]
    fn rejects_a_metabolism_setting_without_a_tape() {
        let off = |params: Params| Params {
            meta_len: 0,
            ..params
        };
        for (params, field) in [
            (
                off(Params {
                    meta_rate: 0.5,
                    ..meta_params()
                }),
                "meta_rate",
            ),
            (off(meta_params()), "meta_draw"),
            (
                off(Params {
                    meta_draw: MetaDraw::Uniform,
                    ..meta_params()
                }),
                "meta_seed",
            ),
        ] {
            assert_eq!(
                params.validate(),
                Err(ParamError::MetaParamWithoutTape { field })
            );
        }
        assert_eq!(
            off(meta_params()).validate().unwrap_err().to_string(),
            "meta_draw is set with meta_len 0: there is no metabolism tape to apply it to"
        );
    }

    #[test]
    fn schema_carries_the_metabolism_tape() {
        let schema: serde_json::Value = serde_json::from_str(&Params::schema_json()).unwrap();
        let fields = schema["fields"].as_array().unwrap();
        let field = |name: &str| fields.iter().find(|f| f["name"] == name).unwrap().clone();
        assert_eq!(field("meta_len")["default"], 0);
        assert_eq!(field("meta_len")["max"], META_LEN_MAX);
        assert_eq!(field("meta_rate")["default"], 0.00390625);
        assert_eq!(
            field("meta_draw")["values"],
            serde_json::json!(["uniform", "isa"])
        );
        assert_eq!(
            field("meta_seed")["values"],
            serde_json::json!(["zeros", "own_tape"])
        );
        assert_eq!(field("meta_seed")["default"], "zeros");
    }

    /// The NAND writes in place unless a run asks for the stack, and a stored run that
    /// predates the parameter reads as the in-place run it was.
    #[test]
    fn the_logic_nand_is_in_place_by_default() {
        assert_eq!(Params::default().logic_nand, LogicNand::InPlace);
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"tasks": "logic"}"#)
                .unwrap()
                .logic_nand,
            LogicNand::InPlace
        );
        let stack = serde_json::from_str::<Params>(r#"{"logic_nand": "stack"}"#).unwrap();
        assert_eq!(stack.logic_nand, LogicNand::Stack);
        assert!(serde_json::from_str::<Params>(r#"{"logic_nand": "accumulator"}"#).is_err());
        assert_eq!(LogicNand::InPlace.assay_ops(), AssayOps::EmitNand);
        assert_eq!(LogicNand::Stack.assay_ops(), AssayOps::EmitStackNand);
    }

    /// `~` is an instruction only in the logic assay, so the stack is accepted under
    /// `tasks = logic` alone, paid or not; the default is accepted everywhere.
    #[test]
    fn rejects_a_stack_nand_away_from_the_logic_ladder() {
        let stacked = |tasks| Params {
            tasks,
            logic_nand: LogicNand::Stack,
            ..rewarded_params()
        };
        assert_eq!(stacked(Tasks::Logic).validate(), Ok(()));
        let unpaid = Params {
            task_reward: 0,
            ..stacked(Tasks::Logic)
        };
        assert_eq!(unpaid.validate(), Ok(()));
        for tasks in [Tasks::Off, Tasks::Arith] {
            let params = Params {
                task_reward: 0,
                ..stacked(tasks)
            };
            assert_eq!(
                params.validate(),
                Err(ParamError::LogicNandWithoutLogic { tasks })
            );
        }
        assert_eq!(
            stacked(Tasks::Arith).validate().unwrap_err().to_string(),
            "logic_nand is stack with tasks arith: ~ is an instruction only in the logic assay"
        );
        for tasks in [Tasks::Off, Tasks::Arith, Tasks::Logic] {
            let params = Params {
                tasks,
                task_reward: 0,
                ..rewarded_params()
            };
            assert_eq!(params.validate(), Ok(()), "{tasks:?}");
        }
    }

    /// The topless ladders accept what the logic ladder accepts, the stack NAND and the
    /// metabolism tape, and a depth cap only they read; a floor other than ECHO is refused,
    /// since they pay every rung.
    #[test]
    fn the_topless_ladders_take_the_logic_ladders_settings_and_a_depth_cap() {
        for tasks in [Tasks::Logic3, Tasks::Logic4] {
            let params = Params {
                tasks,
                logic_nand: LogicNand::Stack,
                meta_len: 32,
                task_depth_cap: 5,
                ..rewarded_params()
            };
            assert_eq!(params.validate(), Ok(()), "{tasks:?}");
            assert_eq!(params.depth_cap(), Some(5));
            assert!(tasks.is_logic());
            assert_eq!(tasks.rungs(), ["echo"]);
            let floored = Params {
                task_floor: "xor".to_string(),
                ..params.clone()
            };
            assert_eq!(
                floored.validate(),
                Err(ParamError::TaskFloorNotARung {
                    task_floor: "xor".to_string(),
                    tasks
                })
            );
            let uncapped = Params {
                task_depth_cap: 0,
                ..params
            };
            assert_eq!(uncapped.depth_cap(), None);
            assert!(Params {
                task_depth_cap: DEPTH_FLOOR + 1,
                ..uncapped
            }
            .validate()
            .is_err());
        }
        assert_eq!(Tasks::Logic3.depth_inputs(), Some(Inputs::Three));
        assert_eq!(Tasks::Logic4.depth_inputs(), Some(Inputs::Four));
        for tasks in [Tasks::Off, Tasks::Arith, Tasks::Logic] {
            assert_eq!(tasks.depth_inputs(), None);
            let capped = Params {
                tasks,
                task_reward: 0,
                task_depth_cap: 5,
                ..rewarded_params()
            };
            assert_eq!(
                capped.validate(),
                Err(ParamError::DepthCapWithoutDepth {
                    task_depth_cap: 5,
                    tasks
                })
            );
        }
        assert_eq!(
            serde_json::from_str::<Params>(r#"{"tasks": "logic4"}"#)
                .unwrap()
                .task_depth_cap,
            0
        );
        assert_eq!(Params::default().task_depth_cap, 0);
    }

    /// The out-compute bundle of the design study (§4.4): an unpaid topless ladder on a
    /// metabolism tape, under the initiator economy.
    fn predatory_params() -> Params {
        Params {
            energy_payer: EnergyPayer::Initiator,
            energy_influx: 1024,
            energy_stock_cap: 65_536,
            tasks: Tasks::Logic4,
            task_reward: 0,
            logic_nand: LogicNand::Stack,
            meta_len: 32,
            meta_draw: MetaDraw::Isa,
            meta_seed: MetaSeed::OwnTape,
            task_max_outputs: 16,
            predation: Predation::SubsetClass,
            predation_transfer: 8192,
            ..Params::default()
        }
    }

    /// Predation is off by default, every relation is read by name, and a stored run that
    /// predates the parameters reads as the run it was.
    #[test]
    fn predation_is_off_by_default() {
        let params = Params::default();
        assert_eq!(
            (
                params.predation,
                params.predation_transfer,
                params.predation_loss,
                params.predation_every,
                params.predation_shadow_p,
                params.task_max_outputs,
            ),
            (Predation::Off, 0, 0.5, 8, 0.3, 4)
        );
        assert!(!params.predates());
        assert_eq!(params.assay_slots(), TASK_MAX_OUTPUTS);
        let stored = serde_json::from_str::<Params>(r#"{"tasks": "logic4"}"#).unwrap();
        assert_eq!(stored.predation, Predation::Off);
        assert_eq!(stored.task_max_outputs, 4);
        for (name, rule) in [
            ("off", Predation::Off),
            ("subset_class", Predation::SubsetClass),
            ("equal", Predation::Equal),
            ("shadow", Predation::Shadow),
            ("count", Predation::Count),
        ] {
            let read =
                serde_json::from_str::<Params>(&format!(r#"{{"predation": "{name}"}}"#)).unwrap();
            assert_eq!(read.predation, rule);
        }
        assert!(serde_json::from_str::<Params>(r#"{"predation": "subset"}"#).is_err());
    }

    #[test]
    fn the_out_compute_bundle_validates_and_predates() {
        let params = predatory_params();
        assert_eq!(params.validate(), Ok(()));
        assert!(params.predates());
        assert_eq!(params.assay_slots(), 16);
        for predation in [Predation::Equal, Predation::Shadow, Predation::Count] {
            assert_eq!(
                Params {
                    predation,
                    ..predatory_params()
                }
                .validate(),
                Ok(())
            );
        }
        let none = Params {
            predation: Predation::Off,
            ..predatory_params()
        };
        assert_eq!(none.validate(), Ok(()), "the none arm reads the same slots");
        assert!(!none.predates());
        let still = Params {
            predation_transfer: 0,
            ..predatory_params()
        };
        assert_eq!(still.validate(), Ok(()));
        assert!(!still.predates(), "a transfer of 0 runs no pass");
    }

    #[test]
    fn predation_is_refused_without_what_it_reads_and_moves() {
        let refused = |params: Params, needs: &'static str| {
            assert_eq!(params.validate(), Err(ParamError::PredationNeeds { needs }));
        };
        refused(
            Params {
                meta_len: 0,
                meta_draw: MetaDraw::Uniform,
                meta_seed: MetaSeed::Zeros,
                ..predatory_params()
            },
            "a metabolism tape (meta_len above 0)",
        );
        refused(
            Params {
                energy_influx: 0,
                energy_payer: EnergyPayer::Pair,
                ..predatory_params()
            },
            "an energy stock (energy_influx above 0)",
        );
        refused(
            Params {
                energy_payer: EnergyPayer::Pair,
                ..predatory_params()
            },
            "the initiator payer (energy_payer initiator)",
        );
        refused(
            Params {
                tasks: Tasks::Logic,
                task_max_outputs: 4,
                ..predatory_params()
            },
            "a topless ladder (tasks logic3 or logic4)",
        );
        assert_eq!(
            Params {
                tasks: Tasks::Logic3,
                ..predatory_params()
            }
            .validate(),
            Ok(())
        );
        let paid = Params {
            task_reward: 1024,
            task_max_outputs: 4,
            ..predatory_params()
        };
        assert_eq!(
            paid.validate(),
            Err(ParamError::PredationPaid { task_reward: 1024 })
        );
        assert_eq!(
            paid.validate().unwrap_err().to_string(),
            "predation is set with a task_reward of 1024: a run is either paid or predatory, \
             never both"
        );
    }

    /// A wider assay is accepted on an unpaid topless ladder alone, so no paid run reads
    /// it, and never past `TASK_MAX_OUTPUTS_LIMIT`.
    #[test]
    fn a_wider_assay_is_refused_outside_an_unpaid_topless_ladder() {
        let wide = |params: Params| Params {
            task_max_outputs: 16,
            predation: Predation::Off,
            ..params
        };
        assert_eq!(wide(predatory_params()).validate(), Ok(()));
        for tasks in [Tasks::Off, Tasks::Arith, Tasks::Logic] {
            let params = wide(Params {
                tasks,
                meta_len: 0,
                meta_draw: MetaDraw::Uniform,
                meta_seed: MetaSeed::Zeros,
                logic_nand: LogicNand::InPlace,
                ..predatory_params()
            });
            assert_eq!(
                params.validate(),
                Err(ParamError::WideAssayOutsideUnpaidTopless {
                    task_max_outputs: 16
                }),
                "{tasks:?}"
            );
        }
        assert_eq!(
            wide(Params {
                task_reward: 1024,
                ..predatory_params()
            })
            .validate(),
            Err(ParamError::WideAssayOutsideUnpaidTopless {
                task_max_outputs: 16
            })
        );
        for task_max_outputs in [3, 17] {
            assert!(matches!(
                Params {
                    task_max_outputs,
                    ..predatory_params()
                }
                .validate(),
                Err(ParamError::OutOfRange {
                    field: "task_max_outputs",
                    ..
                })
            ));
        }
    }

    #[test]
    fn schema_carries_predation() {
        let schema: serde_json::Value = serde_json::from_str(&Params::schema_json()).unwrap();
        let fields = schema["fields"].as_array().unwrap();
        let field = |name: &str| fields.iter().find(|f| f["name"] == name).unwrap().clone();
        assert_eq!(
            field("predation")["values"],
            serde_json::json!(["off", "subset_class", "equal", "shadow", "count"])
        );
        assert_eq!(field("predation")["default"], "off");
        assert_eq!(field("predation_transfer")["default"], 0);
        assert_eq!(field("predation_loss")["default"], 0.5);
        assert_eq!(field("predation_every")["min"], 1);
        assert_eq!(field("predation_shadow_p")["default"], 0.3);
        assert_eq!(
            (
                field("task_max_outputs")["default"].as_i64(),
                field("task_max_outputs")["min"].as_i64(),
                field("task_max_outputs")["max"].as_i64()
            ),
            (Some(4), Some(4), Some(16))
        );
    }

    /// The design study's §13.11 bundle, slice A: strict out-count on the union of 32-byte
    /// genes, a channel growing from 32 bytes to 8 192 by duplication and deletion.
    fn genes_params() -> Params {
        Params {
            predation: Predation::Count,
            meta_max_len: 8192,
            meta_dup: 0.05,
            meta_del: 0.05,
            meta_genes: 32,
            ..predatory_params()
        }
    }

    /// Every new field is off by default, so a stored run reads as the run it was: a fixed
    /// channel of `meta_len` bytes, read whole.
    #[test]
    fn the_growable_channel_and_genes_are_off_by_default() {
        let params = Params::default();
        assert_eq!(
            (
                params.meta_max_len,
                params.meta_min_len,
                params.meta_dup,
                params.meta_del,
                params.meta_seg_max,
                params.meta_genes,
            ),
            (0, 8, 0.0, 0.0, 16, 0)
        );
        let stored: Params =
            serde_json::from_str(r#"{"tasks": "logic4", "meta_len": 32}"#).unwrap();
        assert_eq!(stored.validate(), Ok(()));
        assert_eq!(stored.meta_cap(), 32);
        assert!(!stored.meta_grows());
        assert_eq!(stored.gene_len(), None);
        let fixed = Params {
            meta_max_len: 32,
            ..predatory_params()
        };
        assert_eq!(fixed.validate(), Ok(()));
        assert!(
            !fixed.meta_grows(),
            "a cap of meta_len is the fixed channel"
        );
    }

    #[test]
    fn the_genes_bundle_validates_and_grows() {
        let params = genes_params();
        assert_eq!(params.validate(), Ok(()));
        assert!(params.meta_grows());
        assert_eq!(params.meta_cap(), 8192);
        assert_eq!(params.gene_len(), Some(32));
        assert!(params.predates());
        let drift = Params {
            predation: Predation::Off,
            ..genes_params()
        };
        assert_eq!(drift.validate(), Ok(()), "drift reads genes without a pass");
        assert_eq!(
            Params {
                meta_genes: 0,
                ..genes_params()
            }
            .validate(),
            Ok(())
        );
        assert!(matches!(
            Params {
                meta_max_len: META_LEN_MAX + 1,
                ..genes_params()
            }
            .validate(),
            Err(ParamError::OutOfRange {
                field: "meta_max_len",
                ..
            })
        ));
    }

    #[test]
    fn a_channel_is_refused_bounds_it_cannot_start_inside() {
        let bounds = |meta_min_len, meta_max_len| {
            Params {
                meta_min_len,
                meta_max_len,
                ..genes_params()
            }
            .validate()
        };
        assert_eq!(
            bounds(8, 16),
            Err(ParamError::MetaBounds {
                meta_len: 32,
                meta_min_len: 8,
                meta_max_len: 16
            })
        );
        assert_eq!(
            bounds(33, 64),
            Err(ParamError::MetaBounds {
                meta_len: 32,
                meta_min_len: 33,
                meta_max_len: 64
            })
        );
        assert_eq!(bounds(32, 64), Ok(()));
        assert_eq!(
            bounds(8, 16).unwrap_err().to_string(),
            "meta_len is 32 with meta_min_len 8 and meta_max_len 16: a tape starts at \
             meta_len, so the cap may not sit below it (0 keeps the channel fixed) nor, on a \
             channel that grows, the floor above it"
        );
    }

    /// A variation operator of a channel that cannot grow would be silently inert, and a
    /// channel setting with no tape at all more so.
    #[test]
    fn growth_settings_are_refused_where_they_would_be_inert() {
        let fixed = |params: Params| Params {
            meta_max_len: 0,
            ..params
        };
        for (params, field) in [
            (
                Params {
                    meta_min_len: 4,
                    ..fixed(genes_params())
                },
                "meta_min_len",
            ),
            (fixed(genes_params()), "meta_dup"),
            (
                Params {
                    meta_dup: 0.0,
                    ..fixed(genes_params())
                },
                "meta_del",
            ),
            (
                Params {
                    meta_dup: 0.0,
                    meta_del: 0.0,
                    meta_seg_max: 4,
                    ..fixed(genes_params())
                },
                "meta_seg_max",
            ),
        ] {
            assert_eq!(
                params.validate(),
                Err(ParamError::MetaGrowthWithoutRoom { field })
            );
        }
        let untaped = Params {
            meta_len: 0,
            meta_draw: MetaDraw::Uniform,
            meta_seed: MetaSeed::Zeros,
            predation: Predation::Off,
            ..Params::default()
        };
        for (params, field) in [
            (
                Params {
                    meta_max_len: 64,
                    ..untaped.clone()
                },
                "meta_max_len",
            ),
            (
                Params {
                    meta_genes: 32,
                    ..untaped.clone()
                },
                "meta_genes",
            ),
            (
                Params {
                    meta_del: 0.1,
                    ..untaped.clone()
                },
                "meta_del",
            ),
        ] {
            assert_eq!(
                params.validate(),
                Err(ParamError::MetaParamWithoutTape { field })
            );
        }
    }

    /// Genes split the topless assay of an unpaid run alone, so they never touch pay.
    #[test]
    fn genes_are_refused_off_an_unpaid_topless_ladder() {
        let two_input = Params {
            tasks: Tasks::Logic,
            task_max_outputs: 4,
            predation: Predation::Off,
            ..genes_params()
        };
        assert_eq!(
            two_input.validate(),
            Err(ParamError::GenesNeeds {
                needs: "a topless ladder (tasks logic3 or logic4)"
            })
        );
        let paid = Params {
            predation: Predation::Off,
            task_max_outputs: 4,
            task_reward: 1024,
            ..genes_params()
        };
        assert_eq!(
            paid.validate(),
            Err(ParamError::GenesNeeds {
                needs: "an unpaid run (task_reward 0)"
            })
        );
        assert_eq!(
            paid.validate().unwrap_err().to_string(),
            "meta_genes is set without an unpaid run (task_reward 0): genes split the logic3 \
             or logic4 assay of an unpaid run's metabolism tapes"
        );
    }

    #[test]
    fn schema_carries_the_growable_channel_and_genes() {
        let schema: serde_json::Value = serde_json::from_str(&Params::schema_json()).unwrap();
        let fields = schema["fields"].as_array().unwrap();
        let field = |name: &str| fields.iter().find(|f| f["name"] == name).unwrap().clone();
        assert_eq!(field("meta_len")["max"], 8192);
        assert_eq!(field("meta_max_len")["default"], 0);
        assert_eq!(field("meta_max_len")["max"], 8192);
        assert_eq!(field("meta_min_len")["default"], 8);
        assert_eq!(field("meta_min_len")["min"], 1);
        assert_eq!(field("meta_dup")["default"], 0.0);
        assert_eq!(field("meta_del")["type"], "float");
        assert_eq!(field("meta_seg_max")["default"], 16);
        assert_eq!(field("meta_genes")["default"], 0);
        let names: Vec<&str> = fields.iter().map(|f| f["name"].as_str().unwrap()).collect();
        let at = names.iter().position(|name| *name == "meta_seed").unwrap();
        assert_eq!(
            names[at + 1..at + 7],
            [
                "meta_max_len",
                "meta_min_len",
                "meta_dup",
                "meta_del",
                "meta_seg_max",
                "meta_genes"
            ]
        );
    }
}
