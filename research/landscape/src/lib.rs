//! Offline landscape readings on stored worlds: the methods the Meta-stack sweep locks to be
//! measured after it reads (`docs/design_record.md`, 2026-10-02), ported from the design
//! study's pilot tools (`docs/studies/meta-stack.md`) onto the merged engine. Every rule
//! here is the engine's: the assay, the NAND, the detector and the world are called, never
//! re-implemented, but for the traced stepper, which is held to the engine's interpreter.

pub mod bearing;
pub mod census;
pub mod depth;
pub mod depth_census;
pub mod mcshea;
pub mod paths;
pub mod plant;
pub mod score;
pub mod stored;
pub mod tape;
pub mod trace;
