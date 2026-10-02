//! Truth tables of functions of up to four inputs, and their input-permutation classes.
//!
//! Bit k of a table holds f at the input values read off k, the first input as its most
//! significant bit: on three inputs x = 0xF0, y = 0xCC, z = 0xAA, and on four w = 0xFF00,
//! x = 0xF0F0, y = 0xCCCC, z = 0xAAAA, as the topless study (`docs/studies/topless.md` §1.1)
//! and the engine's logic assay number them.

/// A truth table: bit k is f at row k. Rows past `2^inputs` are zero.
pub type Tt = u16;

/// The functions of `inputs` inputs, `2^(2^inputs)` of them.
pub fn functions(inputs: usize) -> usize {
    1 << rows(inputs)
}

pub fn rows(inputs: usize) -> usize {
    assert!((1..=4).contains(&inputs), "1 to 4 inputs");
    1 << inputs
}

pub fn mask(inputs: usize) -> Tt {
    (((1u32) << rows(inputs)) - 1) as Tt
}

/// The table of input `i` (0 = the first, the most significant).
pub fn input(inputs: usize, i: usize) -> Tt {
    (0..rows(inputs))
        .filter(|k| (k >> (inputs - 1 - i)) & 1 == 1)
        .fold(0, |t, k| t | 1 << k)
}

pub fn nand(inputs: usize, a: Tt, b: Tt) -> Tt {
    !(a & b) & mask(inputs)
}

/// g(v_0, …, v_{n−1}) = f(v_{perm[0]}, …, v_{perm[n−1]}): a circuit for f computes g once its
/// input node j is fed input `perm[j]`.
pub fn permute(inputs: usize, tt: Tt, perm: &[usize]) -> Tt {
    let mut out = 0;
    for k in 0..rows(inputs) {
        let value = |i: usize| (k >> (inputs - 1 - i)) & 1;
        let idx = (0..inputs).fold(0, |idx, j| idx << 1 | value(perm[j]));
        out |= ((tt >> idx) & 1) << k;
    }
    out
}

/// Every permutation of `0..n`, in lexicographic order.
pub fn permutations(n: usize) -> Vec<Vec<usize>> {
    if n == 0 {
        return vec![Vec::new()];
    }
    let mut out = Vec::new();
    for first in 0..n {
        for rest in permutations(n - 1) {
            let mut perm = vec![first];
            perm.extend(rest.into_iter().map(|r| if r >= first { r + 1 } else { r }));
            out.push(perm);
        }
    }
    out
}

/// The input-permutation classes ("P-classes"): `class[f]` is the smallest table among f's
/// permutations, its class representative.
pub fn class_representatives(inputs: usize) -> Vec<Tt> {
    let perms = permutations(inputs);
    (0..functions(inputs))
        .map(|f| {
            perms
                .iter()
                .map(|p| permute(inputs, f as Tt, p))
                .min()
                .expect("one permutation at least")
        })
        .collect()
}

/// The representatives themselves, ascending.
pub fn classes(inputs: usize) -> Vec<Tt> {
    let reps = class_representatives(inputs);
    (0..functions(inputs))
        .filter(|&f| reps[f] == f as Tt)
        .map(|f| f as Tt)
        .collect()
}

/// The permutation taking the class representative `rep` to `f`.
pub fn permutation_to(inputs: usize, rep: Tt, f: Tt) -> Option<Vec<usize>> {
    permutations(inputs)
        .into_iter()
        .find(|p| permute(inputs, rep, p) == f)
}

/// The four-input table of a three-input function of x, y, z (w unread).
pub fn widen3(tt: Tt) -> Tt {
    (0..16).fold(0, |out, k| out | ((tt >> (k & 7)) & 1) << k)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inputs_match_the_study() {
        assert_eq!([input(3, 0), input(3, 1), input(3, 2)], [0xF0, 0xCC, 0xAA]);
        assert_eq!(
            [input(4, 0), input(4, 1), input(4, 2), input(4, 3)],
            [0xFF00, 0xF0F0, 0xCCCC, 0xAAAA]
        );
        assert_eq!([input(2, 0), input(2, 1)], [0xC, 0xA]);
    }

    #[test]
    fn permuting_inputs_swaps_projections() {
        assert_eq!(permute(3, 0xF0, &[1, 0, 2]), 0xCC);
        assert_eq!(permute(4, 0xAAAA, &[0, 1, 3, 2]), 0xCCCC);
        let and_xy = 0xF0 & 0xCC;
        assert_eq!(permute(3, and_xy, &[2, 1, 0]), 0xCC & 0xAA);
    }

    #[test]
    fn class_counts_are_the_known_ones() {
        assert_eq!(classes(2).len(), 12);
        assert_eq!(classes(3).len(), 80);
        assert_eq!(classes(4).len(), 3_984);
    }

    #[test]
    fn widening_keeps_the_projections() {
        assert_eq!(widen3(0xF0), 0xF0F0);
        assert_eq!(widen3(0xCC), 0xCCCC);
        assert_eq!(widen3(0xAA), 0xAAAA);
    }
}
