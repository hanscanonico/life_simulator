//! The topless ladder (`docs/DESIGN.md` §1.1; `docs/studies/topless.md`; the 2026-10-02
//! design-record entry on its engine slice): the logic assay on three or four whole-byte
//! inputs, crediting every non-constant function of them, read off the bit columns of the
//! three cases, and paying each by its exact minimal NAND count. The verdict is a pure
//! function of the tape, the cases, the run's instruction set and its `logic_nand`, as the
//! two-input logic assay's is.
//!
//! A rung is an input-permutation class of non-constant functions: ECHO (the inputs
//! themselves), then the rest by the class's representative, the least truth table among
//! its members. Bit k of a truth table is the function on the row whose input values are
//! k's bits, the first input the most significant: x, y, z on three inputs, w, x, y, z on
//! four, so a three-input function is a four-input one that does not read w
//! (`research/minnand/README.md`).

use crate::bff::OpSet;
use crate::logic::{self, LOGIC_TASKS};
use crate::params::LogicNand;
use crate::rng::{self, Rng};
use crate::task::{
    self, TASK_CAPABILITY_DENOMINATOR, TASK_CASES, TASK_MAX_OUTPUTS, TASK_SAMPLE_CELLS,
};
use std::collections::{BTreeMap, HashMap};
use std::sync::OnceLock;

/// The exact minimal NAND count of every function of three inputs, byte f for truth table
/// f: `research/minnand/data/minnand3.bin`, copied, and held to its README's SHA-256 by a
/// test. The two constants' bytes (0 costs 3, 1 costs 2) are not machine costs and are
/// never read: no slot credits a constant.
const COST3: &[u8; 256] = include_bytes!("../data/minnand3.bin");
/// The same for four inputs, `research/minnand/data/minnand4.bin`. A byte with the high bit
/// set is a proven lower bound with the cost left open: 0x8D, "13 or more", on 604 functions.
const COST4: &[u8; 65_536] = include_bytes!("../data/minnand4.bin");
/// The flag of a lower-bound byte in the cost tables.
const LOWER_BOUND: u8 = 0x80;
/// The depth a "13 or more" function is credited at: a floor, not its cost. A reading that
/// reaches it must say so.
pub const DEPTH_FLOOR: u32 = 13;
/// The units a rung of each depth is worth, `0..=DEPTH_FLOOR`: ×√2 per NAND, √(2^d) rounded
/// to the nearest integer (none is a tie), the topless study's recommended scale (§1.3).
pub const DEPTH_UNITS: [u32; DEPTH_FLOOR as usize + 1] =
    [1, 1, 2, 3, 4, 6, 8, 11, 16, 23, 32, 45, 64, 91];
/// The most case draws one assay epoch makes before it falls back to a fixed set. About a
/// third of three-input draws fail to separate and a few in a thousand four-input ones, so
/// the bound is never reached in practice; it is there so the draw is total and
/// deterministic.
pub const DEPTH_CASE_DRAWS: u32 = 1024;

/// A set of three-input cases that separates, used only if `DEPTH_CASE_DRAWS` draws in a
/// row all failed to: (x, y, z, unused w) per case.
const FALLBACK3: [[u8; 4]; TASK_CASES] = [
    [0x5a, 0x33, 0x0f, 0],
    [0xc6, 0x9f, 0x71, 0],
    [0x21, 0xe8, 0xb4, 0],
];
/// The same for four inputs: (x, y, z, w) per case.
const FALLBACK4: [[u8; 4]; TASK_CASES] = [
    [0xf0, 0xcc, 0xaa, 0x00],
    [0x0f, 0x33, 0x55, 0xff],
    [0x5a, 0x96, 0x3c, 0xe1],
];

/// How many inputs the ladder reads: `tasks = logic3` or `logic4`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Inputs {
    Three,
    Four,
}

impl Inputs {
    pub fn count(self) -> usize {
        match self {
            Self::Three => 3,
            Self::Four => 4,
        }
    }

    fn rows(self) -> usize {
        1 << self.count()
    }

    /// The truth table of the function that is 1 on every row.
    fn mask(self) -> u16 {
        ((1u32 << self.rows()) - 1) as u16
    }

    /// The bit of a row index that input `slot` sets, `slot` counted leftward from the
    /// buffer's last byte as `task::run_case_with` places them: x, y, z, then w, so the
    /// three-input rows are the four-input rows with w clear.
    fn row_bit(slot: usize) -> usize {
        match slot {
            3 => 3,
            _ => 2 - slot,
        }
    }

    /// The truth table of input `slot` itself.
    fn projection(self, slot: usize) -> u16 {
        (0..self.rows())
            .filter(|row| (row >> Self::row_bit(slot)) & 1 == 1)
            .fold(0, |table, row| table | 1 << row)
    }

    /// The minimal NAND count of `function`, the floor for a lower-bound entry.
    pub fn depth(self, function: u16) -> u32 {
        let cost = match self {
            Self::Three => COST3[function as usize],
            Self::Four => COST4[function as usize],
        };
        u32::from(cost & !LOWER_BOUND)
    }

    /// Whether `function`'s depth is only a lower bound, credited at `DEPTH_FLOOR`.
    pub fn at_floor(self, function: u16) -> bool {
        self == Self::Four && COST4[function as usize] & LOWER_BOUND != 0
    }

    /// The rung `function` is credited as: the least truth table among its input
    /// permutations, read off a table built once per process.
    pub fn class_of(self, function: u16) -> u16 {
        self.classes()[function as usize]
    }

    fn classes(self) -> &'static [u16] {
        static THREE: OnceLock<Vec<u16>> = OnceLock::new();
        static FOUR: OnceLock<Vec<u16>> = OnceLock::new();
        let cell = match self {
            Self::Three => &THREE,
            Self::Four => &FOUR,
        };
        cell.get_or_init(|| {
            let perms = self.permutations();
            (0..1usize << self.rows())
                .map(|function| {
                    perms
                        .iter()
                        .map(|perm| self.permute(function as u16, perm))
                        .min()
                        .expect("at least one permutation")
                })
                .collect()
        })
    }

    /// Every permutation of the inputs, as the input each row bit reads from.
    fn permutations(self) -> Vec<Vec<usize>> {
        let n = self.count();
        (0..n.pow(n as u32))
            .map(|code| {
                (0..n)
                    .map(|digit| code / n.pow(digit as u32) % n)
                    .collect::<Vec<_>>()
            })
            .filter(|perm| (0..n).all(|bit| perm.contains(&bit)))
            .collect()
    }

    /// `function` with its inputs relabelled by `perm`: row k of the result is `function`
    /// on the row whose bit `perm[b]` is k's bit b.
    fn permute(self, function: u16, perm: &[usize]) -> u16 {
        (0..self.rows()).fold(0, |table, row| {
            let from = perm
                .iter()
                .enumerate()
                .fold(0, |from, (bit, to)| from | ((row >> bit) & 1) << to);
            table | ((function >> from) & 1) << row
        })
    }

    /// The rung each entry of `logic::LOGIC_TASKS` is on this ladder: the class of its
    /// first form of x and y, so the topless ladder can name the two-input rungs it
    /// credits. A two-input rung is a class, so AND is x ∧ y, x ∧ z or y ∧ z alike.
    pub fn two_input_rungs(self) -> [u16; LOGIC_TASKS.len()] {
        let (x, y) = (self.projection(0), self.projection(1));
        LOGIC_TASKS.map(|task| {
            let byte = |shift: u16| task.expected(0, (x >> shift) as u8, (y >> shift) as u8);
            let table = (u16::from(byte(8)) << 8 | u16::from(byte(0))) & self.mask();
            self.class_of(table)
        })
    }
}

/// The inputs of one assay epoch, shared by every cell: per case, x, y, z and w, the last
/// 0 and unread on three inputs.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Cases {
    inputs: Inputs,
    values: [[u8; 4]; TASK_CASES],
}

impl Cases {
    /// Draws cases from `rng` only until they separate (`separates`).
    ///
    /// - **Three inputs:** whole random bytes, x, y then z for each case.
    /// - **Four inputs:** the designed draw. A random bijection puts each of the 16 rows
    ///   on exactly one of the 16 bit columns of cases 0 and 1, and case 2 is whole random
    ///   bytes, x, y, z then w. Random bytes cover all 16 rows in 24 columns on 0.55% of
    ///   draws, so coverage is built in rather than redrawn for.
    pub fn draw(inputs: Inputs, rng: &mut Rng) -> Self {
        for _ in 0..DEPTH_CASE_DRAWS {
            let values = match inputs {
                Inputs::Three => {
                    std::array::from_fn(|_| [rng::byte(rng), rng::byte(rng), rng::byte(rng), 0])
                }
                Inputs::Four => Self::designed(rng),
            };
            let cases = Self { inputs, values };
            if cases.separates() {
                return cases;
            }
        }
        let values = match inputs {
            Inputs::Three => FALLBACK3,
            Inputs::Four => FALLBACK4,
        };
        Self { inputs, values }
    }

    fn designed(rng: &mut Rng) -> [[u8; 4]; TASK_CASES] {
        let mut rows: [usize; 16] = std::array::from_fn(|row| row);
        rng::shuffle(&mut rows, rng);
        let mut values = [[0u8; 4]; TASK_CASES];
        for (column, row) in rows.into_iter().enumerate() {
            let (case, bit) = (column / 8, column % 8);
            for (slot, value) in values[case].iter_mut().enumerate() {
                *value |= (((row >> Inputs::row_bit(slot)) & 1) as u8) << bit;
            }
        }
        values[2] = std::array::from_fn(|_| rng::byte(rng));
        values
    }

    pub fn new(inputs: Inputs, values: [[u8; 4]; TASK_CASES]) -> Self {
        Self { inputs, values }
    }

    pub fn inputs(&self) -> Inputs {
        self.inputs
    }

    /// Input `slot`'s value in each case.
    fn input(&self, slot: usize) -> [u8; TASK_CASES] {
        self.values.map(|case| case[slot])
    }

    /// The row each bit column reads: per case, per bit.
    fn rows(&self) -> [[u8; 8]; TASK_CASES] {
        self.values.map(|case| {
            std::array::from_fn(|bit| {
                (0..self.inputs.count()).fold(0, |row, slot| {
                    row | ((case[slot] >> bit) & 1) << Inputs::row_bit(slot)
                })
            })
        })
    }

    /// The bytes `function` outputs in each case.
    fn outputs(&self, function: u16) -> [u8; TASK_CASES] {
        let rows = self.rows();
        std::array::from_fn(|case| {
            (0..8).fold(0, |byte, bit| {
                byte | (((function >> rows[case][bit]) & 1) as u8) << bit
            })
        })
    }

    /// Whether the cases separate, the topless study's rules (§1.2):
    ///
    /// - each input's three values are pairwise distinct;
    /// - every row appears on at least one of the 24 bit columns, so an output slot's truth
    ///   table is determined and no two functions expect the same outputs;
    /// - **three inputs only:** no non-constant function expects three equal outputs, so no
    ///   constant passes, and none sits a constant offset from an input but that input
    ///   itself, so no input plus a constant passes, ECHO included.
    ///
    /// On four inputs the last two clauses would refuse nearly every draw, about one
    /// function a draw expecting equal outputs and about four an offset, so they are read
    /// at the slot instead (`Cases::read`).
    pub fn separates(&self) -> bool {
        let distinct = (0..self.inputs.count()).all(|slot| logic::distinct(&self.input(slot)));
        if !distinct || self.covered() != self.inputs.mask() {
            return false;
        }
        match self.inputs {
            Inputs::Three => (1..self.inputs.mask()).all(|function| {
                let outputs = self.outputs(function);
                !equal(&outputs) && !self.offset_from_another_input(&outputs, function)
            }),
            Inputs::Four => true,
        }
    }

    fn covered(&self) -> u16 {
        self.rows()
            .iter()
            .flatten()
            .fold(0, |covered, row| covered | 1 << row)
    }

    /// Whether `outputs` sit a constant offset from some input other than the one
    /// `function` is the projection of.
    fn offset_from_another_input(&self, outputs: &[u8; TASK_CASES], function: u16) -> bool {
        (0..self.inputs.count()).any(|slot| {
            function != self.inputs.projection(slot) && logic::offset_of(outputs, &self.input(slot))
        })
    }

    /// The function one output slot computes, `None` where it computes none that is
    /// credited: a row two columns disagree on (not a bitwise function), a row no column
    /// reads, a constant, three equal output bytes, or outputs a constant offset from an
    /// input the function is not. On three inputs the separating draw already refuses the
    /// last two; on four they are refused here, whatever function the slot matches.
    fn read(&self, outputs: &[u8; TASK_CASES]) -> Option<u16> {
        let (mut ones, mut seen) = (0u16, 0u16);
        for (case, rows) in self.rows().iter().enumerate() {
            for (bit, row) in rows.iter().enumerate() {
                let (row, one) = (1u16 << row, (outputs[case] >> bit) & 1 == 1);
                if seen & row != 0 && (ones & row != 0) != one {
                    return None;
                }
                seen |= row;
                ones |= if one { row } else { 0 };
            }
        }
        let mask = self.inputs.mask();
        let refused = seen != mask
            || ones == 0
            || ones == mask
            || equal(outputs)
            || self.offset_from_another_input(outputs, ones);
        (!refused).then_some(ones)
    }
}

fn equal(outputs: &[u8; TASK_CASES]) -> bool {
    outputs.iter().all(|byte| *byte == outputs[0])
}

/// The rungs one tape was credited with: the classes its output slots compute, each once,
/// greatest first, 0 past the last (no class is 0, the constant).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Credit {
    inputs: Inputs,
    classes: [u16; TASK_MAX_OUTPUTS],
}

impl Credit {
    pub fn none(inputs: Inputs) -> Self {
        Self {
            inputs,
            classes: [0; TASK_MAX_OUTPUTS],
        }
    }

    pub fn classes(&self) -> impl Iterator<Item = u16> + '_ {
        self.classes.iter().copied().take_while(|class| *class != 0)
    }

    pub fn count(&self) -> u32 {
        self.classes().count() as u32
    }

    /// The deepest rung credited, `None` for none.
    pub fn depth(&self) -> Option<u32> {
        self.classes().map(|class| self.inputs.depth(class)).max()
    }

    /// The units the credited rungs are worth together: `DEPTH_UNITS` of each distinct
    /// class's depth, a depth above `cap` paid as `cap`.
    pub fn units(&self, cap: Option<u32>) -> u32 {
        self.classes()
            .map(|class| {
                let depth = self.inputs.depth(class);
                DEPTH_UNITS[cap.map_or(depth, |cap| depth.min(cap)) as usize]
            })
            .sum()
    }

    /// The two-input rungs among those credited, as the logic ladder's credit, with `rungs`
    /// from `Inputs::two_input_rungs`.
    pub fn two_input(&self, rungs: &[u16; LOGIC_TASKS.len()]) -> logic::Credit {
        let bits = rungs
            .iter()
            .enumerate()
            .filter(|(_, rung)| self.classes().any(|class| class == **rung))
            .fold(0u16, |bits, (index, _)| bits | 1 << index);
        logic::Credit::from_bits(bits)
    }

    fn insert(&mut self, class: u16) {
        if self.classes.contains(&class) {
            return;
        }
        if let Some(free) = self.classes.iter_mut().find(|held| **held == 0) {
            *free = class;
        }
        self.classes.sort_unstable_by(|a, b| b.cmp(a));
    }
}

/// The rungs `tape` is credited with on `cases`: every class an output slot computes in
/// all three cases. A tape holding no emit byte is credited nothing and never run.
pub fn assay(tape: &[u8], cases: &Cases, ops: OpSet, nand: LogicNand) -> Credit {
    let mut credit = Credit::none(cases.inputs);
    let count = cases.inputs.count();
    let inputs = cases.values.each_ref().map(|case| &case[..count]);
    let Some(runs) = task::case_outputs_with(tape, inputs, ops, nand.assay_ops()) else {
        return credit;
    };
    for slot in 0..TASK_MAX_OUTPUTS {
        if runs.iter().any(|outputs| outputs.len() <= slot) {
            break;
        }
        let outputs = std::array::from_fn(|case| runs[case][slot]);
        if let Some(function) = cases.read(&outputs) {
            credit.insert(cases.inputs.class_of(function));
        }
    }
    credit
}

/// The topless assay of many tapes on one epoch's cases, each distinct tape run once.
pub struct Memo<'a> {
    cases: Cases,
    ops: OpSet,
    nand: LogicNand,
    seen: HashMap<&'a [u8], Credit>,
}

impl<'a> Memo<'a> {
    pub fn new(cases: Cases, ops: OpSet, nand: LogicNand) -> Self {
        Self {
            cases,
            ops,
            nand,
            seen: HashMap::new(),
        }
    }

    pub fn credit(&mut self, tape: &'a [u8]) -> Credit {
        if !tape.contains(&crate::bff::EMIT) {
            return Credit::none(self.cases.inputs);
        }
        let (cases, ops, nand) = (&self.cases, self.ops, self.nand);
        *self
            .seen
            .entry(tape)
            .or_insert_with(|| assay(tape, cases, ops, nand))
    }
}

/// How many of `task::TASK_SAMPLE_CELLS` sampled cells each rung was credited to: the
/// read-side tally of `logic_depth_max` and `logic_depth_classes`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DepthTally {
    inputs: Inputs,
    credited: BTreeMap<u16, u32>,
}

impl DepthTally {
    pub fn new(inputs: Inputs) -> Self {
        Self {
            inputs,
            credited: BTreeMap::new(),
        }
    }

    pub fn add(&mut self, credit: &Credit) {
        for class in credit.classes() {
            *self.credited.entry(class).or_default() += 1;
        }
    }

    /// The rungs at least a tenth of the sampled cells are credited with, 26 of 256
    /// compared as integers.
    fn held(&self) -> impl Iterator<Item = u16> + '_ {
        self.credited
            .iter()
            .filter(|(_, credited)| **credited * TASK_CAPABILITY_DENOMINATOR >= TASK_SAMPLE_CELLS)
            .map(|(class, _)| *class)
    }

    /// The minimal NAND count of the deepest rung held, −1 where none is: ECHO alone is 0.
    pub fn depth_max(&self) -> i32 {
        self.held()
            .map(|class| self.inputs.depth(class) as i32)
            .max()
            .unwrap_or(-1)
    }

    /// How many rungs are held.
    pub fn classes(&self) -> u32 {
        self.held().count() as u32
    }
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use crate::bff::{self, AssayOps};

    const NANDS: [LogicNand; 2] = [LogicNand::InPlace, LogicNand::Stack];

    /// SHA-256 (FIPS 180-4), for holding the embedded tables to the hashes
    /// `research/minnand/README.md` publishes without a dependency.
    fn sha256(bytes: &[u8]) -> String {
        const K: [u32; 64] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
            0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
            0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
            0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
            0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
            0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
            0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
            0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
            0xc67178f2,
        ];
        let mut h: [u32; 8] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
            0x5be0cd19,
        ];
        let mut message = bytes.to_vec();
        message.push(0x80);
        while message.len() % 64 != 56 {
            message.push(0);
        }
        message.extend_from_slice(&((bytes.len() as u64) * 8).to_be_bytes());
        for block in message.chunks(64) {
            let mut w = [0u32; 64];
            for (t, word) in block.chunks(4).enumerate() {
                w[t] = u32::from_be_bytes([word[0], word[1], word[2], word[3]]);
            }
            for t in 16..64 {
                let s0 = w[t - 15].rotate_right(7) ^ w[t - 15].rotate_right(18) ^ (w[t - 15] >> 3);
                let s1 = w[t - 2].rotate_right(17) ^ w[t - 2].rotate_right(19) ^ (w[t - 2] >> 10);
                w[t] = w[t - 16]
                    .wrapping_add(s0)
                    .wrapping_add(w[t - 7])
                    .wrapping_add(s1);
            }
            let mut v = h;
            for t in 0..64 {
                let s1 = v[4].rotate_right(6) ^ v[4].rotate_right(11) ^ v[4].rotate_right(25);
                let ch = (v[4] & v[5]) ^ (!v[4] & v[6]);
                let t1 = v[7]
                    .wrapping_add(s1)
                    .wrapping_add(ch)
                    .wrapping_add(K[t])
                    .wrapping_add(w[t]);
                let s0 = v[0].rotate_right(2) ^ v[0].rotate_right(13) ^ v[0].rotate_right(22);
                let maj = (v[0] & v[1]) ^ (v[0] & v[2]) ^ (v[1] & v[2]);
                let t2 = s0.wrapping_add(maj);
                v = [
                    t1.wrapping_add(t2),
                    v[0],
                    v[1],
                    v[2],
                    v[3].wrapping_add(t1),
                    v[4],
                    v[5],
                    v[6],
                ];
            }
            for (held, add) in h.iter_mut().zip(v) {
                *held = held.wrapping_add(add);
            }
        }
        h.iter().map(|word| format!("{word:08x}")).collect()
    }

    #[test]
    fn sha256_reads_the_standard_vectors() {
        assert_eq!(
            sha256(b""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        assert_eq!(
            sha256(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    /// The embedded tables are byte for byte the ones `research/minnand` computed and
    /// checked: each hashes to the SHA-256 its README publishes beside its file name.
    #[test]
    fn the_cost_tables_are_research_minnands() {
        let readme = include_str!("../../../../research/minnand/README.md");
        for (name, bytes) in [("minnand3.bin", &COST3[..]), ("minnand4.bin", &COST4[..])] {
            let row = readme
                .lines()
                .find(|line| line.starts_with(&format!("| `data/{name}`")))
                .unwrap_or_else(|| panic!("no README row for {name}"));
            assert!(
                row.contains(&format!("`{}`", sha256(bytes))),
                "{name}: {row}"
            );
        }
    }

    /// The known costs, the four-input table extending the three-input one, and the 604
    /// "13 or more" functions read at the floor.
    #[test]
    fn the_depths_are_the_minimal_nand_counts() {
        let three = [
            (0x96, 8),
            (0xe8, 6),
            (0x01, 7),
            (0x7f, 3),
            (0x80, 4),
            (0xfe, 6),
            (0x16, 10),
        ];
        for (function, depth) in three {
            assert_eq!(Inputs::Three.depth(function), depth, "{function:#04x}");
        }
        assert_eq!(Inputs::Four.depth(0x6996), 12);
        assert_eq!(Inputs::Four.depth(0x9669), 13);
        assert_eq!(Inputs::Four.depth(0x8000), 6);
        for function in 0..=0xffu16 {
            let wide = function | function << 8;
            assert_eq!(
                COST4[wide as usize], COST3[function as usize],
                "{function:#04x}"
            );
            assert!(!Inputs::Three.at_floor(function));
        }
        let floored: Vec<u16> = (0..=0xffffu16)
            .filter(|f| Inputs::Four.at_floor(*f))
            .collect();
        assert_eq!(floored.len(), 604);
        assert!(floored
            .iter()
            .all(|f| Inputs::Four.depth(*f) == DEPTH_FLOOR));
        assert!(Inputs::Four.at_floor(0x0116));
        let deepest = (1..0xffffu16).map(|f| Inputs::Four.depth(f)).max();
        assert_eq!(deepest, Some(DEPTH_FLOOR));
    }

    /// √(2^d) rounded to the nearest integer, in integers: n = ⌊√(2^d)⌋, and one more where
    /// 2^d exceeds n² + n, i.e. where √(2^d) ≥ n + ½.
    #[test]
    fn the_units_are_root_two_per_nand_rounded() {
        for (depth, units) in DEPTH_UNITS.iter().enumerate() {
            let power = 1u64 << depth;
            let floor = (0..=power).take_while(|n| n * n <= power).last().unwrap();
            let rounded = floor + u64::from(power > floor * floor + floor);
            assert_eq!(u64::from(*units), rounded, "depth {depth}");
        }
    }

    /// 78 rungs on three inputs, ECHO and Avida's 77, and 3 982 on four; the logic ladder's
    /// ten rungs are ten distinct classes at their own depths.
    #[test]
    fn the_rungs_are_the_non_constant_permutation_classes() {
        for (inputs, rungs) in [(Inputs::Three, 78), (Inputs::Four, 3_982)] {
            let mut classes: Vec<u16> = (1..inputs.mask())
                .map(|function| inputs.class_of(function))
                .collect();
            classes.sort_unstable();
            classes.dedup();
            assert_eq!(classes.len(), rungs);
            let two = inputs.two_input_rungs();
            for (task, class) in LOGIC_TASKS.iter().zip(two) {
                assert_eq!(inputs.depth(class), task.nands, "{}", task.name);
            }
            let mut distinct = two.to_vec();
            distinct.dedup();
            assert_eq!(distinct.len(), LOGIC_TASKS.len());
            assert!(
                (0..inputs.count()).all(|slot| inputs.class_of(inputs.projection(slot)) == two[0])
            );
        }
    }

    /// Compiles a witness circuit of `research/minnand/data/witnesses*.txt` (the output
    /// node, then each gate's two operands, a base-36 digit a node, inputs first) to a
    /// straight-line tape: every gate's value on a byte of its own, left of the inputs, the
    /// output emitted four times so the run stops there. Under the in-place NAND a gate
    /// copies its first operand onto its byte and NANDs the second into it; under the
    /// stack NAND it copies the first onto the byte right of its own, so `~` writes it.
    pub(crate) fn compile(inputs: Inputs, witness: &str, nand: LogicNand) -> Vec<u8> {
        let nodes: Vec<usize> = witness
            .chars()
            .map(|node| node.to_digit(36).expect("a base-36 node") as usize)
            .collect();
        let n = inputs.count();
        let slot = |input: usize| match inputs {
            Inputs::Three => input,
            Inputs::Four => (input + 3) % 4,
        };
        let place = |node: usize| match node < n {
            true => 1 + slot(node),
            false => 7 + 2 * (node - n),
        };
        let mut code = Vec::new();
        let (mut head0, mut head1) = (0, 0);
        let go = |code: &mut Vec<u8>, head: &mut usize, to: usize, ops: [u8; 2]| {
            while *head < to {
                code.push(ops[0]);
                *head += 1;
            }
            while *head > to {
                code.push(ops[1]);
                *head -= 1;
            }
        };
        let heads0 = [bff::HEAD0_LEFT, bff::HEAD0_RIGHT];
        let heads1 = [bff::HEAD1_LEFT, bff::HEAD1_RIGHT];
        for (gate, operands) in nodes[1..].chunks(2).enumerate() {
            let at = place(n + gate);
            let first = match nand {
                LogicNand::InPlace => at,
                LogicNand::Stack => at - 1,
            };
            go(&mut code, &mut head0, first, heads0);
            go(&mut code, &mut head1, place(operands[0]), heads1);
            code.push(bff::COPY_TO_HEAD0);
            go(&mut code, &mut head1, place(operands[1]), heads1);
            code.push(bff::NAND);
            head0 = at;
        }
        go(&mut code, &mut head0, place(nodes[0]), heads0);
        code.extend([bff::EMIT; TASK_MAX_OUTPUTS]);
        code.resize(code.len().max(64), 0);
        code
    }

    /// Witnesses from `research/minnand/data`: the function each computes, its depth, and
    /// its circuit.
    pub(crate) const SOLVERS: [(Inputs, u16, u32, &str); 8] = [
        (Inputs::Three, 0x96, 8, "a0103134526276789"),
        (Inputs::Three, 0xe8, 6, "8000111352647"),
        (Inputs::Three, 0x01, 7, "900112234565788"),
        (Inputs::Three, 0x16, 10, "c000111223546782979ab"),
        (Inputs::Four, 0x0001, 10, "d0011223345676899abcc"),
        (Inputs::Four, 0x6996, 12, "f0123041425356789abacbcde"),
        (Inputs::Four, 0x0168, 13, "g11122304352646890bab7dceff"),
        (Inputs::Four, 0x0003, 7, "a00112245676899"),
    ];

    /// Each compiled solver computes its function on every output over 4 096 random input
    /// sets, through the assay's own buffer and interpreter, and on 20 000 separating draws
    /// is credited with its own rung and no other, under both NANDs. On four inputs a draw
    /// where the function's outputs are equal or an input plus a constant refuses it, and
    /// only such a draw.
    #[test]
    fn each_solver_is_credited_its_own_rung_alone() {
        for (index, (inputs, function, depth, witness)) in SOLVERS.into_iter().enumerate() {
            assert_eq!(inputs.depth(function), depth);
            for nand in NANDS {
                let tape = compile(inputs, witness, nand);
                let mut rng = rng::seeded(31, index as u64, nand as u64);
                for _ in 0..4_096 {
                    let values =
                        std::array::from_fn(|_| std::array::from_fn(|_| rng::byte(&mut rng)));
                    let cases = Cases::new(inputs, values);
                    for (case, expected) in cases.outputs(function).into_iter().enumerate() {
                        let run = task::run_case_with(
                            &tape,
                            &values[case][..inputs.count()],
                            OpSet::ALL,
                            nand.assay_ops(),
                        );
                        assert_eq!(run.outputs, [expected; TASK_MAX_OUTPUTS], "{witness}");
                    }
                }
                let own = inputs.class_of(function);
                for _ in 0..20_000 {
                    let cases = Cases::draw(inputs, &mut rng);
                    let credit = assay(&tape, &cases, OpSet::ALL, nand);
                    let refused = cases.read(&cases.outputs(function)).is_none();
                    let expected = if refused { 0 } else { own };
                    assert_eq!(credit.classes[..2], [expected, 0], "{witness} on {cases:?}");
                    assert!(inputs == Inputs::Four || !refused, "{witness} on {cases:?}");
                }
                let credit = assay(&tape, &Cases::draw(inputs, &mut rng), OpSet::ALL, nand);
                assert_eq!(credit.depth(), Some(depth));
            }
        }
    }

    /// The two-input ladder's solvers and its evolved stack loop keep their rungs where
    /// they never read the bytes z and w now hold: ECHO `<!` and NOT `<{~!`, and the
    /// stack XOR `<<{~~{{>>~{~!` writes left of y before it reads there.
    #[test]
    fn two_input_solvers_keep_their_rungs_on_the_wider_ladders() {
        let solvers: [(&[u8], LogicNand, usize); 4] = [
            (b"<!", LogicNand::InPlace, 0),
            (b"<{~!", LogicNand::InPlace, 1),
            (b"<<{~!", LogicNand::Stack, 2),
            (b"<<{~~{{>>~{~!", LogicNand::Stack, 8),
        ];
        for inputs in [Inputs::Three, Inputs::Four] {
            let rungs = inputs.two_input_rungs();
            let mut rng = rng::seeded(37, 0, inputs.count() as u64);
            for (code, nand, task) in solvers {
                let mut tape = code.to_vec();
                tape.resize(16, 0);
                for _ in 0..10_000 {
                    let credit = assay(&tape, &Cases::draw(inputs, &mut rng), OpSet::ALL, nand);
                    assert!(
                        credit.classes().all(|class| class == rungs[task]),
                        "{credit:?}"
                    );
                    if inputs == Inputs::Three {
                        assert_eq!(credit.two_input(&rungs).bits(), 1 << task);
                    }
                }
            }
        }
    }

    /// No copying can fake a credit, and no constant: the logic ladder's copiers, junk
    /// emitters, sprayers and inputs plus a constant are credited nothing on either ladder
    /// under either NAND, and a tape that echoes an input ECHO and nothing else.
    #[test]
    fn copiers_constants_and_sprayers_are_credited_nothing_but_echo() {
        let mut copier = b"{[.<>>{]".to_vec();
        copier.resize(64, b'a');
        let mut junk_emit = b"{[.<!>>{]".to_vec();
        junk_emit.resize(64, b'a');
        let mut forward = b"}}}}[,>}!]".to_vec();
        forward.resize(64, 1);
        let mut echoing_copier = b"<!>{[.<>>{]".to_vec();
        echoing_copier.resize(64, b'a');
        let tapes: [(&[u8], bool); 17] = [
            (&copier, false),
            (&junk_emit, false),
            (&forward, false),
            (b"[!+]", false),
            (b"+[!+]", false),
            (b"!!!!", false),
            (b"~!~!~!", false),
            (b"+!+!+!+!", false),
            (b">!", false),
            (b"<+!", false),
            (b"<<---!", false),
            (b"<<<+!", false),
            (&echoing_copier, true),
            (b"<!", true),
            (b"<<!", true),
            (b"<<<!", true),
            (b"<{.!", true),
        ];
        for inputs in [Inputs::Three, Inputs::Four] {
            let echo = inputs.two_input_rungs()[0];
            let mut rng = rng::seeded(3, 0, inputs.count() as u64);
            for nand in NANDS {
                for _ in 0..20_000 {
                    let cases = Cases::draw(inputs, &mut rng);
                    for (code, echoes) in tapes {
                        let mut tape = code.to_vec();
                        tape.resize(tape.len().max(16), 0);
                        let credit = assay(&tape, &cases, OpSet::ALL, nand);
                        let refused_echo = inputs == Inputs::Four && credit.count() == 0;
                        assert!(
                            credit.classes().all(|class| echoes && class == echo)
                                && (!echoes || credit.count() == 1 || refused_echo),
                            "{:?} on {cases:?}: {credit:?}",
                            String::from_utf8_lossy(code)
                        );
                    }
                }
            }
        }
    }

    /// The three-input rule over 10^5 draws, read off the inputs directly: each input's
    /// values distinct, all 8 rows on the 24 columns, and every non-constant function's
    /// outputs neither equal nor an offset of an input it is not; and the fallback holds it.
    #[test]
    fn every_three_input_draw_separates_every_function() {
        let holds = |cases: &Cases| {
            for slot in 0..3 {
                assert!(logic::distinct(&cases.input(slot)), "{cases:?}");
            }
            assert_eq!(cases.covered(), 0xff, "{cases:?}");
            let mut seen = std::collections::HashSet::new();
            for function in 1..0xffu16 {
                let outputs = cases.outputs(function);
                assert!(seen.insert(outputs), "{function:#04x} on {cases:?}");
                assert!(!equal(&outputs), "{function:#04x} on {cases:?}");
                for slot in 0..3 {
                    let own = function == Inputs::Three.projection(slot);
                    assert!(own || !logic::offset_of(&outputs, &cases.input(slot)));
                }
                assert_eq!(cases.read(&outputs), Some(function));
            }
        };
        let mut rng = rng::seeded(11, 0, 0);
        for _ in 0..100_000 {
            holds(&Cases::draw(Inputs::Three, &mut rng));
        }
        holds(&Cases::new(Inputs::Three, FALLBACK3));
    }

    /// The four-input designed draw over 10^5 draws: each input's values distinct, cases 0
    /// and 1 holding each of the 16 rows on exactly one of their 16 columns, so every
    /// function reads back as itself unless the slot refuses it; and the fallback holds it.
    #[test]
    fn every_four_input_draw_covers_every_row() {
        let holds = |cases: &Cases, designed: bool| {
            for slot in 0..4 {
                assert!(logic::distinct(&cases.input(slot)), "{cases:?}");
            }
            let rows = cases.rows();
            let mut first_two: Vec<u8> = rows[..2].iter().flatten().copied().collect();
            first_two.sort_unstable();
            if designed {
                assert_eq!(first_two, (0..16).collect::<Vec<u8>>(), "{cases:?}");
            }
            assert_eq!(cases.covered(), 0xffff);
        };
        let mut rng = rng::seeded(13, 0, 0);
        let mut refused = 0u64;
        for _ in 0..100_000 {
            let cases = Cases::draw(Inputs::Four, &mut rng);
            holds(&cases, true);
            for _ in 0..4 {
                let function = rng::below(&mut rng, 0xfffe) as u16 + 1;
                let outputs = cases.outputs(function);
                match cases.read(&outputs) {
                    Some(read) => assert_eq!(read, function),
                    None => {
                        let offset = (0..4).any(|slot| {
                            function != Inputs::Four.projection(slot)
                                && logic::offset_of(&outputs, &cases.input(slot))
                        });
                        assert!(equal(&outputs) || offset, "{function:#06x} on {cases:?}");
                        refused += 1;
                    }
                }
            }
        }
        assert!(refused < 100, "{refused} of 400 000 reads refused");
        holds(&Cases::new(Inputs::Four, FALLBACK4), false);
    }

    /// The slot-side refusals on four inputs, each on cases built to spring it: three equal
    /// outputs, and an input plus a constant, are credited nothing whatever function they
    /// match; and a slot whose columns disagree on a row is no function at all.
    #[test]
    fn a_four_input_slot_refuses_constants_offsets_and_contradictions() {
        let cases = Cases::new(Inputs::Four, FALLBACK4);
        let function = cases.read(&[0x0f, 0x0f, 0x0f]);
        assert_eq!(function, None);
        let x_plus_one = cases.input(0).map(|x| x.wrapping_add(1));
        assert_eq!(cases.read(&x_plus_one), None);
        assert_eq!(
            cases.read(&cases.input(0)),
            Some(Inputs::Four.projection(0))
        );
        assert_eq!(
            cases.read(&cases.input(3)),
            Some(Inputs::Four.projection(3))
        );
        let three = Cases::new(Inputs::Three, FALLBACK3);
        let mut contradiction = three.outputs(0x96);
        contradiction[2] ^= 1;
        let rows = three.rows();
        let repeated = rows[..2].iter().flatten().any(|row| *row == rows[2][0]);
        assert!(repeated);
        assert_eq!(three.read(&contradiction), None);
    }

    #[test]
    fn the_draw_is_deterministic_and_moves_with_the_stream() {
        for inputs in [Inputs::Three, Inputs::Four] {
            let draw = |epoch| Cases::draw(inputs, &mut rng::seeded(42, 7, epoch));
            assert_eq!(draw(8), draw(8));
            let distinct: std::collections::HashSet<_> = (0..64).map(draw).collect();
            assert_eq!(distinct.len(), 64);
        }
    }

    /// The pay of a credit: each distinct rung once, by depth, a depth above the cap paid as
    /// the cap; MAJ3 and NOR3 together are 8 + 11 units, capped at 5 are 6 + 6.
    #[test]
    fn a_credit_pays_each_distinct_rung_by_its_depth() {
        let mut credit = Credit::none(Inputs::Three);
        for function in [0xe8, 0x01, 0xe8] {
            credit.insert(Inputs::Three.class_of(function));
        }
        assert_eq!(credit.count(), 2);
        assert_eq!(credit.depth(), Some(7));
        assert_eq!(credit.units(None), 8 + 11);
        assert_eq!(credit.units(Some(5)), 6 + 6);
        assert_eq!(credit.units(Some(13)), 8 + 11);
        assert_eq!(Credit::none(Inputs::Four).units(None), 0);
        assert_eq!(Credit::none(Inputs::Four).depth(), None);
        let mut floor = Credit::none(Inputs::Four);
        floor.insert(Inputs::Four.class_of(0x0116));
        assert_eq!(floor.units(None), 91);
    }

    #[test]
    fn a_tape_without_the_emit_byte_is_never_run() {
        let cases = Cases::new(Inputs::Three, FALLBACK3);
        let mut memo = Memo::new(cases, OpSet::ALL, LogicNand::InPlace);
        assert_eq!(memo.credit(b"<{~"), Credit::none(Inputs::Three));
        assert!(memo.seen.is_empty());
    }

    #[test]
    fn the_memo_reads_what_the_assay_reads() {
        for (inputs, _, _, witness) in SOLVERS {
            let tape = compile(inputs, witness, LogicNand::Stack);
            let cases = Cases::draw(inputs, &mut rng::seeded(17, 0, 0));
            let mut memo = Memo::new(cases, OpSet::ALL, LogicNand::Stack);
            let assayed = assay(&tape, &cases, OpSet::ALL, LogicNand::Stack);
            assert_eq!(memo.credit(&tape), assayed);
            assert_eq!(memo.credit(&tape), assayed);
        }
    }

    /// A tenth of 256 is 25.6, so 25 cells hold no rung and 26 do; the deepest held rung
    /// is read, not the deepest credited, and none held reads −1.
    #[test]
    fn a_rung_is_held_at_a_tenth_of_the_sampled_cells_counted_in_integers() {
        let inputs = Inputs::Three;
        let credit = |functions: &[u16]| {
            let mut credit = Credit::none(inputs);
            for function in functions {
                credit.insert(inputs.class_of(*function));
            }
            credit
        };
        let mut tally = DepthTally::new(inputs);
        assert_eq!((tally.depth_max(), tally.classes()), (-1, 0));
        for _ in 0..25 {
            tally.add(&credit(&[0xf0, 0x96]));
        }
        assert_eq!((tally.depth_max(), tally.classes()), (-1, 0));
        tally.add(&credit(&[0xf0]));
        assert_eq!((tally.depth_max(), tally.classes()), (0, 1));
        tally.add(&credit(&[0xaa, 0x96]));
        assert_eq!((tally.depth_max(), tally.classes()), (8, 2));
    }

    /// Every program of up to `len` bytes over the ten ops, `!` and `~` holding an emit, in
    /// front of a zero tail, on `draws` separating draws of `inputs` under `nand`: the most
    /// draws on which any one is credited a rung of depth `depth` or more, and that program.
    fn deepest_cheap_credit(
        len: u32,
        draws: u32,
        depth: u32,
        inputs: Inputs,
        nand: LogicNand,
    ) -> (u32, Vec<u8>) {
        let alphabet: Vec<u8> = bff::OPS
            .iter()
            .copied()
            .chain([bff::EMIT, bff::NAND])
            .collect();
        let symbols = alphabet.len() as u64;
        let mut rng = rng::seeded(19, len.into(), inputs.count() as u64);
        let sets: Vec<Cases> = (0..draws).map(|_| Cases::draw(inputs, &mut rng)).collect();
        let mut worst = (0, Vec::new());
        for length in 1..=len {
            for code in 0..symbols.pow(length) {
                let mut tape: Vec<u8> = (0..length)
                    .map(|digit| alphabet[(code / symbols.pow(digit) % symbols) as usize])
                    .collect();
                if !tape.contains(&bff::EMIT) {
                    continue;
                }
                tape.resize(16, 0);
                let deep = sets
                    .iter()
                    .filter(|cases| assay(&tape, cases, OpSet::ALL, nand).depth() >= Some(depth))
                    .count() as u32;
                if deep > worst.0 {
                    worst = (deep, tape);
                }
            }
        }
        worst
    }

    /// No program of up to four bytes is credited a rung of depth 9 or more on a tenth of
    /// 200 draws of either ladder under either NAND, so not even a world of nothing else
    /// would read it held in one sample in ten (the full search is
    /// `the_false_deep_credit_search`).
    #[test]
    fn no_cheap_program_is_credited_a_deep_rung_on_a_tenth_of_draws() {
        for inputs in [Inputs::Three, Inputs::Four] {
            for nand in NANDS {
                let (deep, tape) = deepest_cheap_credit(4, 200, 9, inputs, nand);
                assert!(
                    deep < 20,
                    "{inputs:?} {nand:?}: {deep} of 200, {:?}",
                    String::from_utf8_lossy(&tape)
                );
            }
        }
    }

    /// The false-deep-credit search of the design record, on demand: every program of up
    /// to five bytes on 200 draws, the worst of each re-read on 10 000. `cargo test -p
    /// life-engine --release -- --ignored the_false_deep_credit_search --nocapture`.
    #[test]
    #[ignore]
    fn the_false_deep_credit_search() {
        for inputs in [Inputs::Three, Inputs::Four] {
            for nand in NANDS {
                for depth in 5..=10 {
                    let (deep, tape) = deepest_cheap_credit(5, 200, depth, inputs, nand);
                    let mut rng = rng::seeded(23, u64::from(depth), inputs.count() as u64);
                    let reread = (0..10_000)
                        .filter(|_| {
                            let cases = Cases::draw(inputs, &mut rng);
                            !tape.is_empty()
                                && assay(&tape, &cases, OpSet::ALL, nand).depth() >= Some(depth)
                        })
                        .count();
                    println!(
                        "{inputs:?} {nand:?} depth >= {depth}: {deep} of 200 draws, {reread} of \
                         10000 re-read, {:?}",
                        String::from_utf8_lossy(&tape).trim_end_matches('\0')
                    );
                }
            }
        }
    }

    /// The arithmetic and two-input logic machines are untouched: `run_case_on` is
    /// `run_case_with` on x and y.
    #[test]
    fn two_inputs_sit_where_they_always_sat() {
        let tape = b"<!<!{{{.!";
        for (x, y) in [(3, 5), (0xa5, 0x5a)] {
            for ops in [AssayOps::Emit, AssayOps::EmitNand, AssayOps::EmitStackNand] {
                assert_eq!(
                    task::run_case_on(tape, x, y, OpSet::ALL, ops),
                    task::run_case_with(tape, &[x, y], OpSet::ALL, ops)
                );
            }
        }
    }
}
