//! Exact minimal NAND circuit costs of every Boolean function of two, three and four inputs:
//! the depth scale of the topless study's nested ladder (`docs/studies/topless.md` §1.1, §1.5).
//!
//! The cost of f is the fewest two-input NAND gates of a circuit computing f from its inputs,
//! fan-out free of charge; NOT a = NAND(a, a) is one gate. Constants are not given, so the
//! constant 1 costs 2 and 0 costs 3. The machine gets a constant byte for free and credits
//! none, so those two entries are not its costs; free constants change no other (README).
//! A cost is exact by exhaustive canonical enumeration up to a gate count; above it, by a
//! witness at a class's proven lower bound (an exact class's witness extended by a gate or
//! two, or SAT), with UNSAT raising the bound. Every claimed cost carries a witness circuit;
//! a cost left open is stored as a lower bound.

pub mod circuit;
pub mod enumerate;
pub mod sat;
pub mod table;
pub mod tt;
