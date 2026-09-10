//! Simulation parameters: names, defaults, validated ranges and the JSON schema Rails
//! reads, all in one place (`docs/DESIGN.md` §3, "parameters are data").

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
    /// Moore-neighbourhood radius; `0` means well-mixed (any cell in the world).
    pub radius: u32,
    pub max_steps: u32,
    /// Probability that a given byte is replaced by a random one, per byte per epoch.
    pub mutation_rate: f64,
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
            radius: 1,
            max_steps: 8192,
            mutation_rate: 1.0 / 4096.0,
            init: Init::Random,
            sample_every: 10,
            top_k: 16,
            snapshot_every: 100,
        }
    }
}

enum Kind {
    Choice(&'static [&'static str]),
    Integer { min: f64, max: f64 },
    Float { min: f64, max: f64 },
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
        name: "radius",
        kind: Kind::Integer {
            min: 0.0,
            max: 64.0,
        },
        doc: "Moore-neighbourhood radius an interaction reaches; 0 means well-mixed.",
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
        name: "mutation_rate",
        kind: Kind::Float { min: 0.0, max: 1.0 },
        doc: "Probability a byte is replaced by a random byte, per byte per epoch.",
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
                Kind::Choice(_) => continue,
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
        Ok(())
    }

    /// A JSON description of every parameter — name, type, default, range and doc — for
    /// Rails to build forms and validations from (`runner schema`).
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
        serde_json::to_string_pretty(&serde_json::json!({ "fields": fields }))
            .expect("schema always serialises")
    }

    /// Bytes of state one cell holds: a whole tape in the soup, one byte in life.
    pub fn stride(&self) -> usize {
        match self.substrate {
            Substrate::Soup => self.tape_len as usize,
            Substrate::Life => 1,
        }
    }

    pub fn cell_count(&self) -> usize {
        self.width as usize * self.height as usize
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
        assert_eq!(fields.len(), 11);

        let width = fields.iter().find(|f| f["name"] == "width").unwrap();
        assert_eq!(width["type"], "integer");
        assert_eq!(width["default"], 128);
        assert_eq!(width["min"], 4);
        assert_eq!(width["max"], 1024);

        let substrate = fields.iter().find(|f| f["name"] == "substrate").unwrap();
        assert_eq!(substrate["type"], "enum");
        assert_eq!(substrate["values"], serde_json::json!(["soup", "life"]));
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
}
