//! The committed tables in `data/`: their hashes, the study's checked values, the witnesses,
//! permutation invariance and the known costs.

use minnand::enumerate::enumerate;
use minnand::sat;
use minnand::table::{self, Table, AT_LEAST};
use minnand::tt::{self, Tt};
use std::collections::HashMap;

/// Keep in sync with the hashes in README.md.
const SHA3: &str = "66d5ba949ef999c3be27db4c3414227bdebed71f5e4570d884017854a12a0da3";
const SHA4: &str = "5f15454855cbfe384bbd065604a7938b7e9e9c38e8b9a770fbd5e523056d13ae";

/// The SHA-256 of the study's `minnand4_best_10.bin`: its four-input costs to 10 gates, 255
/// above (`docs/studies/topless.md` §1.1).
const STUDY4_TO_10: &str = "3c8835ef9a48b21eb0cf312b918b1bfd20cb3937524301c5f3c436006ddacfb2";

fn data(name: &str) -> String {
    format!("{}/data/{name}", env!("CARGO_MANIFEST_DIR"))
}

fn table(inputs: usize) -> Table {
    let bytes = std::fs::read(data(&format!("minnand{inputs}.bin"))).expect("the table");
    let text =
        std::fs::read_to_string(data(&format!("witnesses{inputs}.txt"))).expect("the witnesses");
    Table::parse(inputs, &bytes, &text).expect("a well-formed table")
}

fn threads() -> usize {
    std::thread::available_parallelism().map_or(1, |n| n.get())
}

const X: Tt = 0xF0;
const Y: Tt = 0xCC;
const Z: Tt = 0xAA;

#[test]
fn the_data_files_match_their_hashes() {
    assert_eq!(table::sha256_hex(table(3).bytes()), SHA3);
    assert_eq!(table::sha256_hex(table(4).bytes()), SHA4);
}

#[test]
fn the_three_input_table_is_the_studys_checked_table() {
    let text = include_str!("study3.txt");
    let study: HashMap<Tt, u8> = text
        .lines()
        .filter(|l| !l.starts_with('#'))
        .map(|l| {
            let (class, cost) = l.split_once(' ').expect("class cost");
            (
                Tt::from_str_radix(class, 16).unwrap(),
                cost.parse().unwrap(),
            )
        })
        .collect();
    let reps = tt::class_representatives(3);
    assert_eq!(study.len(), 80);
    let t = table(3);
    for f in 0..256 {
        assert_eq!(t.cost[f], study[&reps[f]], "function {f:02x}");
    }
}

#[test]
fn the_three_input_table_is_re_derived_by_exhaustion() {
    let t = table(3);
    assert_eq!(enumerate(3, 10, threads(), false).cost, t.cost);
    assert_eq!(enumerate(3, 10, threads(), true).cost, t.cost);
}

#[test]
fn every_three_input_lower_bound_is_unsat() {
    let t = table(3);
    for class in tt::classes(3) {
        let cost = t.cost[class as usize] as usize;
        for k in 1..cost {
            assert!(
                sat::synthesize(3, class, k).is_none(),
                "class {class:02x} in {k} gates"
            );
        }
        if cost > 0 {
            let w = sat::synthesize(3, class, cost).expect("a circuit at the cost");
            assert_eq!(w.eval(), Some(class));
        }
    }
}

#[test]
fn every_witness_re_evaluates_at_its_cost() {
    table(3).check_witnesses().unwrap();
    table(4).check_witnesses().unwrap();
}

#[test]
fn the_proof_logs_account_for_every_cost_past_the_enumeration() {
    for inputs in [3, 4] {
        let text =
            std::fs::read_to_string(data(&format!("proofs{inputs}.txt"))).expect("the proof log");
        table::parse_proofs(inputs, &text)
            .unwrap()
            .check(&table(inputs))
            .unwrap();
    }
}

#[test]
fn the_four_input_table_is_the_studys_to_ten_gates() {
    let to_ten: Vec<u8> = table(4)
        .cost
        .iter()
        .map(|&c| {
            if c & AT_LEAST == 0 && c <= 10 {
                c
            } else {
                u8::MAX
            }
        })
        .collect();
    assert_eq!(table::sha256_hex(&to_ten), STUDY4_TO_10);
}

#[test]
fn the_four_input_table_extends_the_three_input_one() {
    let (three, four) = (table(3), table(4));
    for f in 0..256 {
        assert_eq!(
            four.cost[tt::widen3(f as Tt) as usize],
            three.cost[f],
            "function {f:02x}"
        );
    }
}

#[test]
fn costs_are_invariant_under_input_permutation() {
    for inputs in [3, 4] {
        let t = table(inputs);
        let perms = tt::permutations(inputs);
        for f in 0..tt::functions(inputs) {
            for p in &perms {
                let g = tt::permute(inputs, f as Tt, p);
                assert_eq!(t.cost[g as usize], t.cost[f], "{f:04x} under {p:?}");
            }
        }
    }
}

#[test]
fn the_two_input_ladder_costs_are_the_logic_ladders() {
    let e = enumerate(2, 8, 1, false);
    let (x, y) = (0xC, 0xA);
    let cost = |f: Tt| e.cost[(f & 0xF) as usize];
    let ladder = [
        (x, 0),
        (!x, 1),
        (!(x & y), 1),
        (x & y, 2),
        (x | !y, 2),
        (x | y, 3),
        (x & !y, 3),
        (!(x | y), 4),
        (x ^ y, 4),
        (!(x ^ y), 5),
    ];
    for (f, nands) in ladder {
        assert_eq!(cost(f), nands, "{:x}", f & 0xF);
    }
}

#[test]
fn the_known_three_input_costs() {
    let t = table(3);
    let cost = |f: Tt| t.cost[(f & 0xFF) as usize];
    assert_eq!(cost(X ^ Y), 4, "XOR");
    assert_eq!(cost(!(X ^ Y)), 5, "EQU");
    assert_eq!(cost(X ^ Y ^ Z), 8, "XOR3, the full adder's sum");
    assert_eq!(
        cost((X & Y) | (X & Z) | (Y & Z)),
        6,
        "MAJ3, the full adder's carry"
    );
    assert_eq!(cost(!(X & Y & Z)), 3, "NAND3");
    assert_eq!(cost(X & Y & Z), 4, "AND3");
    assert_eq!(cost(X | Y | Z), 6, "OR3");
    assert_eq!(cost(!(X | Y | Z)), 7, "NOR3");
    assert_eq!(cost(!(X ^ Y ^ Z)), 9, "XNOR3");
    assert_eq!(cost(0x16), 10, "exactly one of three, the top");
    assert_eq!(*t.cost.iter().max().unwrap(), 10);
}

#[test]
fn the_full_adder_together_is_nine() {
    let (sum, carry) = (X ^ Y ^ Z, (X & Y) | (X & Z) | (Y & Z));
    assert!(sat::synthesize_all(3, &[sum, carry], 8).is_none());
    assert!(sat::synthesize_all(3, &[sum, carry], 9).is_some());
}

#[test]
fn the_known_four_input_costs() {
    let t = table(4);
    let (w, x, y, z) = (0xFF00, 0xF0F0, 0xCCCC, 0xAAAA);
    let cost = |f: Tt| t.cost[f as usize];
    assert_eq!(cost(w & x & y & z), 6, "AND4");
    assert_eq!(cost(w | x | y | z), 9, "OR4");
    assert_eq!(cost((w & x) | (!w & y)), 4, "MUX");
    assert_eq!(cost(w ^ x ^ y ^ z), 12, "XOR4");
    assert_eq!(cost(!(w ^ x ^ y ^ z)), 13, "XNOR4");
    assert_eq!(
        cost(0x0116),
        AT_LEAST | 13,
        "exactly one of four, left at 13 or more"
    );
    assert_eq!(
        *t.cost.iter().filter(|&&c| c & AT_LEAST == 0).max().unwrap(),
        13
    );
}

/// A spot check of the exhaustion by SAT: four cost-9 classes have no 8-gate circuit. The
/// exhaustion itself is re-run only by `minnand enumerate`.
#[test]
fn a_sample_of_four_input_lower_bounds_is_unsat() {
    let t = table(4);
    for class in tt::classes(4)
        .into_iter()
        .filter(|&c| t.cost[c as usize] == 9)
        .take(4)
    {
        assert!(
            sat::synthesize(4, class, 8).is_none(),
            "class {class:04x} in 8 gates"
        );
    }
}
