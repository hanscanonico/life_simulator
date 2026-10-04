//! The topless ladder (`docs/DESIGN.md` §1.1; `docs/studies/topless.md`; the 2026-10-02
//! design-record entry on its engine slice): the logic assay on three or four whole-byte
//! inputs, crediting every non-constant function of them, read off the bit columns of its
//! cases, every row at three bit positions, and paying each by its exact minimal NAND count. The verdict is a pure
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
    self, TASK_CAPABILITY_DENOMINATOR, TASK_MAX_OUTPUTS, TASK_MAX_OUTPUTS_LIMIT, TASK_SAMPLE_CELLS,
};
use std::borrow::Cow;
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
/// How many times the cases read each row of the inputs, each time at a bit position they
/// read it at no other time. A program that computes a different function at different
/// bit positions, a NAND masked by a code byte, then contradicts itself on some row, where
/// a row read once would read the mix as one deep function.
pub const READS_PER_ROW: usize = 3;
/// The most cases an assay epoch runs: the four-input ladder's 16 rows read three times
/// over 8-bit columns.
pub const DEPTH_MAX_CASES: usize = 6;
/// The most case draws one assay epoch makes before it falls back to a fixed set, and the
/// most shuffles one read of the rows makes before its draw fails. No bound is reached in
/// practice; they are there so the draw is total and deterministic.
pub const DEPTH_CASE_DRAWS: u32 = 1024;

/// A set of three-input cases that separates, used only if `DEPTH_CASE_DRAWS` draws in a
/// row all failed to: (x, y, z, unused w) per case, the unused cases 0.
const FALLBACK3: [[u8; 4]; DEPTH_MAX_CASES] = [
    [0x99, 0xcc, 0x2d, 0],
    [0x9a, 0x4e, 0x53, 0],
    [0x2e, 0xa5, 0xb2, 0],
    [0; 4],
    [0; 4],
    [0; 4],
];
/// The same for four inputs: (x, y, z, w) per case.
const FALLBACK4: [[u8; 4]; DEPTH_MAX_CASES] = [
    [0xc6, 0x4a, 0x0f, 0x5a],
    [0xb2, 0xce, 0x63, 0x39],
    [0x4e, 0x87, 0x65, 0x85],
    [0x69, 0xc3, 0x5a, 0x3d],
    [0xbc, 0x3a, 0x30, 0x91],
    [0xc2, 0x33, 0xfc, 0x67],
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

    /// How many cases the ladder runs: `READS_PER_ROW` reads of its rows, each over as
    /// many cases as the rows fill bytes, three on three inputs and six on four.
    pub fn cases(self) -> usize {
        READS_PER_ROW * self.cases_per_read()
    }

    fn cases_per_read(self) -> usize {
        self.rows() / 8
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

/// The inputs of one assay epoch, shared by every cell: per case, x, y, z and w, w 0 and
/// unread on three inputs; the cases past `Inputs::cases` are 0 and never run.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Cases {
    inputs: Inputs,
    values: [[u8; 4]; DEPTH_MAX_CASES],
    /// The row each bit column reads: per case, per bit.
    rows: [[u8; 8]; DEPTH_MAX_CASES],
}

impl Cases {
    /// Draws cases from `rng` only until they separate (`separates`). The draw is
    /// designed: `READS_PER_ROW` times over, a random bijection puts each row on exactly
    /// one bit column of that read's cases, reshuffled until no row lands on a bit
    /// position an earlier read put it on. Random bytes cover all 16 four-input rows in
    /// 24 columns on 0.55% of draws, and leave a row read once at one bit position, which
    /// a masked NAND passes as a deep function.
    pub fn draw(inputs: Inputs, rng: &mut Rng) -> Self {
        for _ in 0..DEPTH_CASE_DRAWS {
            if let Some(values) = Self::designed(inputs, rng) {
                let cases = Self::new(inputs, values);
                if cases.separates() {
                    return cases;
                }
            }
        }
        let values = match inputs {
            Inputs::Three => FALLBACK3,
            Inputs::Four => FALLBACK4,
        };
        Self::new(inputs, values)
    }

    fn designed(inputs: Inputs, rng: &mut Rng) -> Option<[[u8; 4]; DEPTH_MAX_CASES]> {
        let rows = inputs.rows();
        let mut positions = [0u8; 16];
        let mut values = [[0u8; 4]; DEPTH_MAX_CASES];
        for read in 0..READS_PER_ROW {
            let mut order: [usize; 16] = std::array::from_fn(|row| row);
            let order = &mut order[..rows];
            let mut placed = false;
            for _ in 0..DEPTH_CASE_DRAWS {
                rng::shuffle(order, rng);
                placed = order
                    .iter()
                    .enumerate()
                    .all(|(column, row)| positions[*row] & 1 << (column % 8) == 0);
                if placed {
                    break;
                }
            }
            if !placed {
                return None;
            }
            for (column, row) in order.iter().enumerate() {
                let (case, bit) = (read * inputs.cases_per_read() + column / 8, column % 8);
                positions[*row] |= 1 << bit;
                for (slot, value) in values[case][..inputs.count()].iter_mut().enumerate() {
                    *value |= (((row >> Inputs::row_bit(slot)) & 1) as u8) << bit;
                }
            }
        }
        Some(values)
    }

    pub fn new(inputs: Inputs, values: [[u8; 4]; DEPTH_MAX_CASES]) -> Self {
        let rows = values.map(|case| {
            std::array::from_fn(|bit| {
                (0..inputs.count()).fold(0, |row, slot| {
                    row | ((case[slot] >> bit) & 1) << Inputs::row_bit(slot)
                })
            })
        });
        Self {
            inputs,
            values,
            rows,
        }
    }

    pub fn inputs(&self) -> Inputs {
        self.inputs
    }

    /// The cases the ladder runs.
    fn run(&self) -> &[[u8; 4]] {
        &self.values[..self.inputs.cases()]
    }

    /// Input `slot`'s value in each case run.
    fn input(&self, slot: usize) -> Vec<u8> {
        self.run().iter().map(|case| case[slot]).collect()
    }

    /// The row each bit column reads: per case run, per bit.
    fn rows(&self) -> &[[u8; 8]] {
        &self.rows[..self.inputs.cases()]
    }

    /// The bytes `function` outputs in each case run.
    fn outputs(&self, function: u16) -> Vec<u8> {
        self.rows()
            .iter()
            .map(|rows| {
                (0..8).fold(0, |byte, bit| {
                    byte | (((function >> rows[bit]) & 1) as u8) << bit
                })
            })
            .collect()
    }

    /// Whether the cases separate, the topless study's rules (§1.2) and the reads apart:
    ///
    /// - each input's values are pairwise distinct;
    /// - every row is read at `READS_PER_ROW` distinct bit positions or more, so an output
    ///   slot's truth table is determined, no two functions expect the same outputs, and a
    ///   function that differs between bit positions on a row contradicts itself there;
    /// - **three inputs only:** no non-constant function expects equal outputs, so no
    ///   constant passes, and none sits a constant offset from an input but that input
    ///   itself, so no input plus a constant passes, ECHO included.
    ///
    /// On four inputs the last clause would be read over 65 534 functions a draw, so it is
    /// read at the slot instead (`Cases::read`).
    pub fn separates(&self) -> bool {
        let distinct = (0..self.inputs.count()).all(|slot| {
            let values = self.input(slot);
            (1..values.len()).all(|j| !values[..j].contains(&values[j]))
        });
        let mut positions = [0u8; 16];
        for rows in self.rows() {
            for (bit, row) in rows.iter().enumerate() {
                positions[*row as usize] |= 1 << bit;
            }
        }
        let apart = positions[..self.inputs.rows()]
            .iter()
            .all(|read| read.count_ones() as usize >= READS_PER_ROW);
        if !distinct || !apart {
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

    /// Whether `outputs` sit a constant offset from some input other than the one
    /// `function` is the projection of.
    fn offset_from_another_input(&self, outputs: &[u8], function: u16) -> bool {
        (0..self.inputs.count()).any(|slot| {
            let offset = outputs[0].wrapping_sub(self.values[0][slot]);
            function != self.inputs.projection(slot)
                && outputs
                    .iter()
                    .zip(self.run())
                    .all(|(output, case)| output.wrapping_sub(case[slot]) == offset)
        })
    }

    /// The function one output slot computes, `None` where it computes none that is
    /// credited: a row two columns disagree on (not a bitwise function, or not the same
    /// one at every bit position), a row no column reads, a constant, equal output bytes,
    /// or outputs a constant offset from an input the function is not. On three inputs the
    /// separating draw already refuses the last two; on four they are refused here,
    /// whatever function the slot matches.
    fn read(&self, outputs: &[u8]) -> Option<u16> {
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

fn equal(outputs: &[u8]) -> bool {
    outputs.iter().all(|byte| *byte == outputs[0])
}

/// The rungs one tape was credited with: the classes its output slots compute, each once,
/// greatest first, 0 past the last (no class is 0, the constant). Two credits of one ladder
/// are equal exactly when they hold the same set of classes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Credit {
    inputs: Inputs,
    classes: [u16; TASK_MAX_OUTPUTS_LIMIT],
}

impl Credit {
    pub fn none(inputs: Inputs) -> Self {
        Self {
            inputs,
            classes: [0; TASK_MAX_OUTPUTS_LIMIT],
        }
    }

    /// Whether every class `other` holds is one this credit holds too, the out-compute
    /// relation of `predation = subset_class`: the empty credit is covered by every credit,
    /// and every credit covers itself.
    pub fn covers(&self, other: &Self) -> bool {
        other
            .classes()
            .all(|class| self.classes().any(|held| held == class))
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
/// every case run. A tape holding no emit byte is credited nothing and never run.
pub fn assay(tape: &[u8], cases: &Cases, ops: OpSet, nand: LogicNand) -> Credit {
    assay_upto(tape, cases, ops, nand, TASK_MAX_OUTPUTS)
}

/// `assay` over the first `slots` output slots, each case stopping at its `slots`-th emit
/// (at most `TASK_MAX_OUTPUTS_LIMIT`). The first `TASK_MAX_OUTPUTS` slots read what
/// `assay` reads, so a wider reading only ever adds classes.
pub fn assay_upto(tape: &[u8], cases: &Cases, ops: OpSet, nand: LogicNand, slots: usize) -> Credit {
    let mut credit = Credit::none(cases.inputs);
    let count = cases.inputs.count();
    let inputs = cases.values.each_ref().map(|case| &case[..count]);
    let run = &inputs[..cases.inputs.cases()];
    let slots = slots.min(TASK_MAX_OUTPUTS_LIMIT);
    let Some(runs) = task::case_outputs_upto(tape, run, ops, nand.assay_ops(), slots) else {
        return credit;
    };
    for slot in 0..slots {
        if runs.iter().any(|outputs| outputs.len() <= slot) {
            break;
        }
        let outputs: [u8; DEPTH_MAX_CASES] =
            std::array::from_fn(|case| runs.get(case).map_or(0, |outputs| outputs[slot]));
        if let Some(function) = cases.read(&outputs[..runs.len()]) {
            credit.insert(cases.inputs.class_of(function));
        }
    }
    credit
}

/// A metabolism tape's genes under `meta_genes` (`docs/DESIGN.md` §1.1, "Genes"): its
/// bytes cut at offsets 0, G, 2G and so on, each gene `gene_len` bytes, the last
/// zero-padded to `gene_len`. A gene is assayed as a tape of its own, so it runs alone on a
/// buffer of 2G bytes with the inputs at its end, and no gene reads another's bytes.
pub fn genes(tape: &[u8], gene_len: usize) -> impl Iterator<Item = Cow<'_, [u8]>> {
    tape.chunks(gene_len.max(1)).map(move |gene| {
        if gene.len() == gene_len {
            return Cow::Borrowed(gene);
        }
        let mut padded = gene.to_vec();
        padded.resize(gene_len, 0);
        Cow::Owned(padded)
    })
}

/// The classes a tape computes: one credit's, or under genes the union of its genes'
/// credits, which may hold more classes than one credit has slots for. Two repertoires
/// are equal exactly when they hold the same set.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Repertoire {
    /// Ascending, each class once.
    classes: Vec<u16>,
}

impl Repertoire {
    /// The union of `credits`' classes.
    pub fn union<'c>(credits: impl IntoIterator<Item = &'c Credit>) -> Self {
        let mut classes: Vec<u16> = credits.into_iter().flat_map(Credit::classes).collect();
        classes.sort_unstable();
        classes.dedup();
        Self { classes }
    }

    pub fn classes(&self) -> impl Iterator<Item = u16> + '_ {
        self.classes.iter().copied()
    }

    pub fn count(&self) -> u32 {
        self.classes.len() as u32
    }

    /// `Credit::covers` on the union: every class `other` holds is one this holds too.
    pub fn covers(&self, other: &Self) -> bool {
        other
            .classes
            .iter()
            .all(|class| self.classes.binary_search(class).is_ok())
    }

    /// `Credit::two_input` on the union.
    pub fn two_input(&self, rungs: &[u16; LOGIC_TASKS.len()]) -> logic::Credit {
        let bits = rungs
            .iter()
            .enumerate()
            .filter(|(_, rung)| self.classes.binary_search(rung).is_ok())
            .fold(0u16, |bits, (index, _)| bits | 1 << index);
        logic::Credit::from_bits(bits)
    }
}

/// How many of a tape's genes are essential, read off its genes' credits (the design
/// study's §10.1): the genes grouped by the set of classes they compute, copies computing
/// the same set being one group, and a group counted when it computes a class no other
/// group computes. A duplicate counts once, a diverged copy that adds a class counts
/// again, and a gene whose classes other genes compute between them, or that computes
/// none, counts nothing.
pub fn essential_genes(credits: &[Credit]) -> u32 {
    let mut groups: Vec<&Credit> = Vec::new();
    for credit in credits.iter().filter(|credit| credit.count() > 0) {
        if !groups.contains(&credit) {
            groups.push(credit);
        }
    }
    let mut computed: Vec<u16> = groups.iter().flat_map(|group| group.classes()).collect();
    computed.sort_unstable();
    let alone = |class: u16| {
        let from = computed.partition_point(|held| *held < class);
        computed.get(from + 1) != Some(&class)
    };
    groups
        .iter()
        .filter(|group| group.classes().any(alone))
        .count() as u32
}

/// The topless assay of many tapes on one epoch's cases, each distinct tape run once, and
/// under genes each distinct gene.
pub struct Memo<'a> {
    cases: Cases,
    ops: OpSet,
    nand: LogicNand,
    slots: usize,
    gene_len: Option<usize>,
    seen: HashMap<Cow<'a, [u8]>, Credit>,
}

impl<'a> Memo<'a> {
    pub fn new(cases: Cases, ops: OpSet, nand: LogicNand) -> Self {
        Self::upto(cases, ops, nand, TASK_MAX_OUTPUTS)
    }

    /// The memo of `assay_upto` over `slots` output slots.
    pub fn upto(cases: Cases, ops: OpSet, nand: LogicNand, slots: usize) -> Self {
        Self {
            cases,
            ops,
            nand,
            slots,
            gene_len: None,
            seen: HashMap::new(),
        }
    }

    /// The same memo reading a tape as genes of `gene_len` bytes where it is set: what
    /// `repertoire` and `gene_credits` read. `credit` still runs a tape whole.
    pub fn genes(self, gene_len: Option<usize>) -> Self {
        Self { gene_len, ..self }
    }

    pub fn credit(&mut self, tape: &'a [u8]) -> Credit {
        self.credit_of(Cow::Borrowed(tape))
    }

    fn credit_of(&mut self, tape: Cow<'a, [u8]>) -> Credit {
        if !tape.contains(&crate::bff::EMIT) {
            return Credit::none(self.cases.inputs);
        }
        if let Some(credit) = self.seen.get(tape.as_ref()) {
            return *credit;
        }
        let credit = assay_upto(&tape, &self.cases, self.ops, self.nand, self.slots);
        self.seen.insert(tape, credit);
        credit
    }

    /// The credit of each of `tape`'s genes in order, or of the whole tape where the memo
    /// reads no genes.
    pub fn gene_credits(&mut self, tape: &'a [u8]) -> Vec<Credit> {
        match self.gene_len {
            None => vec![self.credit(tape)],
            Some(gene_len) => genes(tape, gene_len)
                .map(|gene| self.credit_of(gene))
                .collect(),
        }
    }

    /// The classes `tape` computes: its credit, or the union of its genes'.
    pub fn repertoire(&mut self, tape: &'a [u8]) -> Repertoire {
        Repertoire::union(&self.gene_credits(tape))
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

    /// Counts one sampled cell's classes, each once.
    pub fn add(&mut self, classes: impl IntoIterator<Item = u16>) {
        for class in classes {
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

    /// Whether `outputs` sit one constant offset, mod 256, from `input` in every case.
    fn offset_of(outputs: &[u8], input: &[u8]) -> bool {
        let offset = outputs[0].wrapping_sub(input[0]);
        outputs
            .iter()
            .zip(input)
            .all(|(output, value)| output.wrapping_sub(*value) == offset)
    }

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

    /// Each input's values pairwise distinct, and each read of the rows a bijection onto
    /// its cases' columns, every row at `READS_PER_ROW` distinct bit positions: read off
    /// the inputs directly, not through `separates`.
    fn holds_the_reads(cases: &Cases) {
        let inputs = cases.inputs;
        for slot in 0..inputs.count() {
            let values = cases.input(slot);
            for j in 1..values.len() {
                assert!(!values[..j].contains(&values[j]), "{cases:?}");
            }
        }
        assert!(cases.values[inputs.cases()..]
            .iter()
            .all(|case| *case == [0; 4]));
        let rows = cases.rows();
        let mut positions = vec![Vec::new(); inputs.rows()];
        for read in rows.chunks(inputs.cases_per_read()) {
            let mut seen: Vec<u8> = read.iter().flatten().copied().collect();
            seen.sort_unstable();
            assert_eq!(
                seen,
                (0..inputs.rows() as u8).collect::<Vec<_>>(),
                "{cases:?}"
            );
            for case in read {
                for (bit, row) in case.iter().enumerate() {
                    positions[*row as usize].push(bit);
                }
            }
        }
        for mut bits in positions {
            bits.sort_unstable();
            bits.dedup();
            assert_eq!(bits.len(), READS_PER_ROW, "{cases:?}");
        }
    }

    /// The three-input rule over 10^5 draws: the reads apart, and every non-constant
    /// function's outputs neither equal nor an offset of an input it is not, and read back
    /// as itself; and the fallback holds it.
    #[test]
    fn every_three_input_draw_separates_every_function() {
        let holds = |cases: &Cases| {
            holds_the_reads(cases);
            let mut seen = std::collections::HashSet::new();
            for function in 1..0xffu16 {
                let outputs = cases.outputs(function);
                assert!(seen.insert(outputs.clone()), "{function:#04x} on {cases:?}");
                assert!(!equal(&outputs), "{function:#04x} on {cases:?}");
                for slot in 0..3 {
                    let own = function == Inputs::Three.projection(slot);
                    assert!(own || !offset_of(&outputs, &cases.input(slot)));
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

    /// The four-input rule over 10^5 draws: the reads apart, so every function reads back
    /// as itself unless the slot refuses it as equal outputs or an input plus a constant,
    /// which six cases almost never spring; and the fallback holds it.
    #[test]
    fn every_four_input_draw_reads_every_row_three_times_apart() {
        let mut rng = rng::seeded(13, 0, 0);
        let mut refused = 0u64;
        for _ in 0..100_000 {
            let cases = Cases::draw(Inputs::Four, &mut rng);
            holds_the_reads(&cases);
            for _ in 0..4 {
                let function = rng::below(&mut rng, 0xfffe) as u16 + 1;
                let outputs = cases.outputs(function);
                match cases.read(&outputs) {
                    Some(read) => assert_eq!(read, function),
                    None => {
                        let offset = (0..4).any(|slot| {
                            function != Inputs::Four.projection(slot)
                                && offset_of(&outputs, &cases.input(slot))
                        });
                        assert!(equal(&outputs) || offset, "{function:#06x} on {cases:?}");
                        refused += 1;
                    }
                }
            }
        }
        assert!(refused < 10, "{refused} of 400 000 reads refused");
        let fallback = Cases::new(Inputs::Four, FALLBACK4);
        holds_the_reads(&fallback);
        assert!(fallback.separates());
    }

    /// The slot-side refusals on four inputs, each on cases built to spring it: equal
    /// outputs, and an input plus a constant, are credited nothing whatever function they
    /// match; a slot whose columns disagree on a row is no function at all; and a NAND
    /// masked by a code byte, a different function at different bit positions, contradicts
    /// itself on a row read where the mask differs.
    #[test]
    fn a_four_input_slot_refuses_constants_offsets_and_contradictions() {
        let cases = Cases::new(Inputs::Four, FALLBACK4);
        assert_eq!(cases.read(&[0x0f; 6]), None);
        let x_plus_one: Vec<u8> = cases.input(0).iter().map(|x| x.wrapping_add(1)).collect();
        assert_eq!(cases.read(&x_plus_one), None);
        assert_eq!(
            cases.read(&cases.input(0)),
            Some(Inputs::Four.projection(0))
        );
        assert_eq!(
            cases.read(&cases.input(3)),
            Some(Inputs::Four.projection(3))
        );
        let mut contradiction = cases.outputs(0x6996);
        contradiction[5] ^= 1;
        assert_eq!(cases.read(&contradiction), None);
        for inputs in [Inputs::Three, Inputs::Four] {
            let cases = Cases::draw(inputs, &mut rng::seeded(29, 0, 0));
            let masked: Vec<u8> = cases.input(0).iter().map(|x| !(x & 0x0f)).collect();
            assert_eq!(cases.read(&masked), None, "{cases:?}");
        }
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

    /// The out-compute relation: a credit covers each subset of its classes, itself
    /// included, and the empty credit; the empty credit covers only itself.
    #[test]
    fn a_credit_covers_every_subset_of_its_classes() {
        let credit = |functions: &[u16]| {
            let mut credit = Credit::none(Inputs::Three);
            for function in functions {
                credit.insert(Inputs::Three.class_of(*function));
            }
            credit
        };
        let (none, maj, both) = (credit(&[]), credit(&[0xe8]), credit(&[0xe8, 0x96]));
        assert!(none.covers(&none));
        assert!(maj.covers(&none) && both.covers(&none));
        assert!(!none.covers(&maj));
        assert!(both.covers(&maj) && both.covers(&both));
        assert!(!maj.covers(&both));
        assert!(!credit(&[0x96]).covers(&maj));
        assert_eq!(
            credit(&[0x96, 0xe8]),
            both,
            "a credit is its set of classes"
        );
    }

    /// A tape that emits x four times and then XOR4: the engine's four slots read ECHO
    /// alone, sixteen read XOR4 too, and the first four read the same either way.
    #[test]
    fn a_wider_assay_reads_the_slots_past_the_fourth() {
        let (_, _, _, witness) = SOLVERS
            .into_iter()
            .find(|(inputs, function, _, _)| *inputs == Inputs::Four && *function == 0x6996)
            .unwrap();
        let mut tape = vec![bff::HEAD0_LEFT];
        tape.extend([bff::EMIT; TASK_MAX_OUTPUTS]);
        tape.push(bff::HEAD0_RIGHT);
        tape.extend(compile(Inputs::Four, witness, LogicNand::Stack));
        for seed in 0..8 {
            let cases = Cases::draw(Inputs::Four, &mut rng::seeded(seed, 0, 0));
            let four = assay(&tape, &cases, OpSet::ALL, LogicNand::Stack);
            assert_eq!(four.depth(), Some(0), "seed {seed}");
            assert_eq!(four.count(), 1);
            assert_eq!(
                assay_upto(
                    &tape,
                    &cases,
                    OpSet::ALL,
                    LogicNand::Stack,
                    TASK_MAX_OUTPUTS
                ),
                four
            );
            let wide = assay_upto(&tape, &cases, OpSet::ALL, LogicNand::Stack, 16);
            assert_eq!((wide.count(), wide.depth()), (2, Some(12)), "seed {seed}");
            assert!(wide.covers(&four));
            let mut memo = Memo::upto(cases, OpSet::ALL, LogicNand::Stack, 16);
            assert_eq!(memo.credit(&tape), wide);
        }
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
            tally.add(credit(&[0xf0, 0x96]).classes());
        }
        assert_eq!((tally.depth_max(), tally.classes()), (-1, 0));
        tally.add(credit(&[0xf0]).classes());
        assert_eq!((tally.depth_max(), tally.classes()), (0, 1));
        tally.add(credit(&[0xaa, 0x96]).classes());
        assert_eq!((tally.depth_max(), tally.classes()), (8, 2));
    }

    /// Every program of up to `len` bytes over the ten ops, `!` and `~` holding an emit, in
    /// front of a zero tail, on `draws` separating draws of `inputs` under `nand`: for each
    /// depth of `depths`, the `keep` programs credited a rung that deep or deeper on the
    /// most draws, with how many, most first.
    fn deepest_cheap_credits(
        len: u32,
        draws: u32,
        depths: std::ops::RangeInclusive<u32>,
        inputs: Inputs,
        nand: LogicNand,
        keep: usize,
    ) -> Vec<Vec<(u32, Vec<u8>)>> {
        let alphabet: Vec<u8> = bff::OPS
            .iter()
            .copied()
            .chain([bff::EMIT, bff::NAND])
            .collect();
        let symbols = alphabet.len() as u64;
        let mut rng = rng::seeded(19, len.into(), inputs.count() as u64);
        let sets: Vec<Cases> = (0..draws).map(|_| Cases::draw(inputs, &mut rng)).collect();
        let mut worst: Vec<Vec<(u32, Vec<u8>)>> = depths.clone().map(|_| Vec::new()).collect();
        for length in 1..=len {
            for code in 0..symbols.pow(length) {
                let mut tape: Vec<u8> = (0..length)
                    .map(|digit| alphabet[(code / symbols.pow(digit) % symbols) as usize])
                    .collect();
                if !tape.contains(&bff::EMIT) {
                    continue;
                }
                tape.resize(16, 0);
                let credited: Vec<Option<u32>> = sets
                    .iter()
                    .map(|cases| assay(&tape, cases, OpSet::ALL, nand).depth())
                    .collect();
                for (nearest, depth) in worst.iter_mut().zip(depths.clone()) {
                    let deep = credited.iter().filter(|d| **d >= Some(depth)).count() as u32;
                    if deep > 0 {
                        nearest.push((deep, tape.clone()));
                        nearest.sort_by_key(|(deep, _)| std::cmp::Reverse(*deep));
                        nearest.truncate(keep);
                    }
                }
            }
        }
        worst
    }

    /// No program of up to four bytes is credited a rung of depth 5 or more on more than
    /// one of 200 draws of either ladder under either NAND (the full search is
    /// `the_false_deep_credit_search`).
    #[test]
    fn no_cheap_program_is_credited_a_deep_rung() {
        for inputs in [Inputs::Three, Inputs::Four] {
            for nand in NANDS {
                let worst = deepest_cheap_credits(4, 200, 5..=5, inputs, nand, 1);
                if let Some((deep, tape)) = worst[0].first() {
                    assert!(
                        *deep <= 1,
                        "{inputs:?} {nand:?}: {deep} of 200, {:?}",
                        String::from_utf8_lossy(tape)
                    );
                }
            }
        }
    }

    /// The false-deep-credit search of the design record, on demand: every program of up
    /// to five bytes on 400 draws, the six nearest at each depth re-read on 20 000 fresh
    /// ones. `cargo test -p life-engine --release -- --ignored the_false_deep_credit_search
    /// --nocapture`.
    #[test]
    #[ignore]
    fn the_false_deep_credit_search() {
        let searches: Vec<_> = [Inputs::Three, Inputs::Four]
            .into_iter()
            .flat_map(|inputs| NANDS.map(|nand| (inputs, nand)))
            .map(|(inputs, nand)| {
                std::thread::spawn(move || {
                    let worst = deepest_cheap_credits(5, 400, 5..=10, inputs, nand, 6);
                    let mut rng = rng::seeded(23, 0, inputs.count() as u64);
                    let fresh: Vec<Cases> =
                        (0..20_000).map(|_| Cases::draw(inputs, &mut rng)).collect();
                    let rows: Vec<String> = worst
                        .iter()
                        .zip(5..=10)
                        .map(|(nearest, depth)| {
                            let reread = |tape: &Vec<u8>| {
                                fresh
                                    .iter()
                                    .filter(|cases| {
                                        assay(tape, cases, OpSet::ALL, nand).depth() >= Some(depth)
                                    })
                                    .count()
                            };
                            let (deep, tape) = nearest
                                .iter()
                                .map(|(_, tape)| (reread(tape), tape.clone()))
                                .max_by_key(|(deep, _)| *deep)
                                .unwrap_or_default();
                            format!(
                                "{inputs:?} {nand:?} depth >= {depth}: {deep} of 20000, {:?}",
                                String::from_utf8_lossy(&tape).trim_end_matches('\0')
                            )
                        })
                        .collect();
                    rows.join("\n")
                })
            })
            .collect();
        for search in searches {
            println!("{}", search.join().expect("a search"));
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

    /// The genes of the design study's §10.1 checks: two stack-NAND loops, a tandem variant
    /// of the first, and an emit of x, each run alone in 32 bytes.
    pub(crate) const LOOP: &[u8] = b"<<<<[!{~!~]";
    pub(crate) const TANDEM: &[u8] = b"<<<<[!{~!{~!~]";
    const ECHO: &[u8] = b"<!";

    fn gene_memo<'a>(gene_len: usize) -> Memo<'a> {
        let cases = Cases::draw(Inputs::Four, &mut rng::seeded(1, 2, 3));
        Memo::upto(cases, OpSet::ALL, LogicNand::Stack, 16).genes(Some(gene_len))
    }

    /// `pieces` laid at offsets 0, `gene_len`, `2 * gene_len` and so on, zero between them.
    pub(crate) fn laid(pieces: &[&[u8]], gene_len: usize) -> Vec<u8> {
        let mut tape = Vec::new();
        for piece in pieces {
            let mut gene = piece.to_vec();
            gene.resize(gene_len, 0);
            tape.extend(gene);
        }
        tape
    }

    #[test]
    fn genes_cut_at_fixed_offsets_and_pad_the_last() {
        let cut: Vec<Cow<'_, [u8]>> = genes(b"abcdefghij", 4).collect();
        assert_eq!(cut, [&b"abcd"[..], b"efgh", b"ij\0\0"]);
        assert!(matches!(cut[0], Cow::Borrowed(_)));
        assert!(matches!(cut[2], Cow::Owned(_)));
        assert_eq!(genes(b"abcd", 4).count(), 1);
        assert_eq!(genes(b"", 4).count(), 0);
    }

    /// A gene is read alone: whatever follows it, a gene's credit is its own run on a
    /// buffer of twice its length, so a later gene can add classes to the tape and never
    /// change or remove an earlier gene's.
    #[test]
    fn a_later_gene_cannot_change_an_earlier_genes_classes() {
        let alone = laid(&[LOOP], 32);
        let mut rng = rng::seeded(9, 0, 0);
        let mut tails: Vec<Vec<u8>> = (0..64)
            .map(|_| {
                let len = 1 + rng::below(&mut rng, 96) as usize;
                (0..len).map(|_| rng::byte(&mut rng)).collect()
            })
            .collect();
        tails.push(laid(&[TANDEM, ECHO], 32));
        tails.push(b"]]]][[[[".to_vec());
        let tapes: Vec<Vec<u8>> = tails
            .iter()
            .map(|tail| [alone.clone(), tail.clone()].concat())
            .collect();
        let mut memo = gene_memo(32);
        let own = assay_upto(&alone, &memo.cases, OpSet::ALL, LogicNand::Stack, 16);
        assert!(own.count() > 4);
        for tape in &tapes {
            let credits = memo.gene_credits(tape);
            assert_eq!(credits[0], own);
            assert!(memo.repertoire(tape).covers(&Repertoire::union([&own])));
        }
    }

    /// The tape computes the union of its genes' classes, which may hold more than one
    /// credit has slots for; a whole run of the same bytes reads one orbit.
    #[test]
    fn a_tape_computes_the_union_of_its_genes() {
        let pair = laid(&[LOOP, TANDEM, ECHO], 32);
        let mut memo = gene_memo(32);
        let credits = memo.gene_credits(&pair);
        assert_eq!(credits.len(), 3);
        let expected: std::collections::BTreeSet<u16> =
            credits.iter().flat_map(Credit::classes).collect();
        let union = memo.repertoire(&pair);
        assert_eq!(
            union.classes().collect::<Vec<_>>(),
            Vec::from_iter(expected)
        );
        assert!(union.count() > credits[0].count().max(credits[1].count()));
        assert!(union.count() > TASK_MAX_OUTPUTS_LIMIT as u32);
        for credit in &credits {
            assert!(union.covers(&Repertoire::union([credit])));
        }
        let whole = Memo::upto(memo.cases, OpSet::ALL, LogicNand::Stack, 16).repertoire(&pair);
        assert!(whole.count() <= TASK_MAX_OUTPUTS_LIMIT as u32);
        assert_ne!(whole, union);
    }

    /// Essential genes, the study's §10.1: copies computing one set count once, a gene
    /// another covers or that computes nothing counts nothing, a diverged copy that adds a
    /// class counts again.
    #[test]
    fn essential_genes_count_the_groups_that_compute_a_class_alone() {
        let inputs = Inputs::Four;
        let credit = |classes: &[u16]| {
            let mut credit = Credit::none(inputs);
            for class in classes {
                credit.insert(*class);
            }
            credit
        };
        let (a, b, c) = (credit(&[3, 5]), credit(&[5, 7]), credit(&[3, 7]));
        let silent = Credit::none(inputs);
        assert_eq!(essential_genes(&[]), 0);
        assert_eq!(essential_genes(&[silent, silent]), 0);
        assert_eq!(essential_genes(&[a]), 1);
        assert_eq!(
            essential_genes(&[a, a, silent, a]),
            1,
            "copies are one group"
        );
        assert_eq!(
            essential_genes(&[a, credit(&[3, 5, 9])]),
            1,
            "a covered gene adds none"
        );
        assert_eq!(essential_genes(&[a, credit(&[9])]), 2);
        assert_eq!(
            essential_genes(&[a, b, c]),
            0,
            "each class is computed by two groups"
        );
        assert_eq!(essential_genes(&[a, b, c, credit(&[11])]), 1);
        let read = |pieces: &[&[u8]]| {
            let tape = laid(pieces, 32);
            let mut memo = gene_memo(32);
            essential_genes(&memo.gene_credits(&tape))
        };
        assert_eq!(read(&[LOOP, LOOP]), 1);
        assert_eq!(read(&[LOOP, TANDEM]), 2);
        assert_eq!(
            read(&[LOOP, &[], ECHO, LOOP]),
            1,
            "the loop emits x too, so the ECHO gene adds no class of its own"
        );
        assert_eq!(read(&[TANDEM, LOOP, ECHO]), 2);
    }

    /// Repertoires relate as credits do, on sets of any size.
    #[test]
    fn repertoires_cover_count_and_compare_as_sets() {
        let inputs = Inputs::Four;
        let credit = |classes: &[u16]| {
            let mut credit = Credit::none(inputs);
            for class in classes {
                credit.insert(*class);
            }
            credit
        };
        let (a, b) = (credit(&[3, 5]), credit(&[5, 7]));
        let both = Repertoire::union([&a, &b]);
        assert_eq!(both.count(), 3);
        assert_eq!(both, Repertoire::union([&b, &a, &a]));
        assert!(both.covers(&Repertoire::union([&a])));
        assert!(!Repertoire::union([&a]).covers(&both));
        assert!(Repertoire::default().count() == 0 && both.covers(&Repertoire::default()));
        assert_eq!(Repertoire::union([&a]).count(), a.count());
        assert!(Repertoire::union([&a]).covers(&Repertoire::union([&a])));
    }
}
