//! Simulation parameters: names, defaults, validated ranges and the JSON schema Rails
//! reads, all in one place (`docs/DESIGN.md` §3, "parameters are data").

use crate::bff::OpSet;
use crate::metrics::{
    TRANSITION_HOLD_SAMPLES, TRANSITION_MAX_OP_DENSITY, TRANSITION_MIN_ALPHABET_SIZE,
    TRANSITION_THRESHOLD,
};
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
            ops: crate::bff::OPS.iter().map(|op| *op as char).collect(),
            mutation_rate: 1.0 / 4096.0,
            structure: Structure::Uniform,
            structure_amplitude: 0.5,
            interaction: Interaction::Concat,
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
              across epochs up to energy_stock_cap rather than being refilled to it. An \
              interaction runs on what the poorer of its two cells holds, both are \
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
    /// A stock that cannot hold one epoch's influx is no stock: the surplus would be
    /// thrown away the moment it arrived, and the economy would be the per-epoch
    /// allowance `energy_per_epoch` already is.
    StockCapBelowInflux {
        energy_stock_cap: u32,
        energy_influx: u32,
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
            Self::StockCapBelowInflux {
                energy_stock_cap,
                energy_influx,
            } => write!(
                f,
                "energy_stock_cap is {energy_stock_cap}, below the energy_influx of \
                 {energy_influx}: a stock must hold at least one epoch's influx"
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
        if self.radius > 0 && 2 * self.radius + 1 > self.width.min(self.height) {
            return Err(ParamError::RadiusTooWide {
                radius: self.radius,
                width: self.width,
                height: self.height,
            });
        }
        Ok(())
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
        assert_eq!(fields.len(), 19);

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
}
