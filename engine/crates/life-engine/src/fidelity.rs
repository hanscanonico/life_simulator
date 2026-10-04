//! Heritable staged fidelity (`docs/DESIGN.md` §1.1, "Fidelity"; `docs/design_record.md`,
//! 2026-10-04, Genes slice B): the law a cell's fidelity level sets on its metabolism
//! tape's substitution rate, and the price it initiates at.
//!
//! Both are computed without a float transcendental, so native and wasm read the same
//! numbers: the rate is `meta_rate` scaled by a power of two and, at an odd level, by the
//! constant 1/√2, one rounded product; the price is integer fixed-point arithmetic whose
//! only irrational inputs are integer square roots.

use crate::params::{Params, META_FID_MAX};
use std::f64::consts::FRAC_1_SQRT_2;

/// The fixed-point scale of the price's power of two: Q62, so every product of two
/// factors below 2 fits a `u128`.
const SCALE_BITS: u32 = 62;
const ONE: u128 = 1 << SCALE_BITS;
/// The bits `meta_fid_alpha` is read to: α is rounded to a multiple of 2^-32 (an error
/// below 10^-9, far below any price's rounding), and α·f/2 is then a multiple of 2^-33.
const ALPHA_BITS: u32 = 32;
const EXPONENT_BITS: u32 = ALPHA_BITS + 1;

/// The factor level `level` multiplies `meta_rate` by: 2^(−level/2), each level √2 more
/// faithful than the one below. Exact at an even level; at an odd one, 1/√2 (the constant,
/// correctly rounded) scaled by a power of two, which is exact too.
pub fn rate_factor(level: u32) -> f64 {
    let halved = 1.0 / (1u64 << (level / 2)) as f64;
    match level % 2 {
        0 => halved,
        _ => FRAC_1_SQRT_2 * halved,
    }
}

/// The substitution rate of a metabolism tape at fidelity `level`.
pub fn rate(meta_rate: f64, level: u32) -> f64 {
    meta_rate * rate_factor(level)
}

/// What a cell at fidelity `level` pays to initiate: `max_steps` × 2^(α·level/2), rounded
/// to the nearest integer (a half up), never past `u32::MAX`. Each halving of the error
/// rate multiplies it by 2^α: the scale-free cost of kinetic proofreading, which names no
/// preferred rate. At α = 0 or level 0 it is `max_steps` exactly.
pub fn price(max_steps: u32, alpha: f64, level: u32) -> u32 {
    let alpha = (alpha * (1u64 << ALPHA_BITS) as f64).round() as u128;
    let exponent = alpha * u128::from(level);
    let whole = (exponent >> EXPONENT_BITS) as u32;
    let fraction = exp2_fraction(exponent & ((1 << EXPONENT_BITS) - 1));
    let scaled = (u128::from(max_steps) * fraction) << whole;
    u32::try_from((scaled + (ONE >> 1)) >> SCALE_BITS).unwrap_or(u32::MAX)
}

/// The price of every level of `params`' range, 0 to `meta_fid_max`.
pub fn prices(params: &Params) -> Vec<u32> {
    (0..=params.meta_fid_max.min(META_FID_MAX))
        .map(|level| price(params.max_steps, params.meta_fid_alpha, level))
        .collect()
}

/// 2^x in Q62 for x a multiple of 2^-33 in [0, 1): the product of 2^(2^-k) over the bits
/// k of x, each root the integer square root of the one before, starting from 2.
fn exp2_fraction(bits: u128) -> u128 {
    let mut root = 2 * ONE;
    let mut product = ONE;
    for k in 1..=EXPONENT_BITS {
        root = (root << SCALE_BITS).isqrt();
        if bits & (1 << (EXPONENT_BITS - k)) != 0 {
            product = (product * root + (ONE >> 1)) >> SCALE_BITS;
        }
    }
    product
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_level_divides_the_rate_by_the_square_root_of_two_exactly() {
        for half in 0..=8u32 {
            let power = 1.0 / f64::from(1u32 << half);
            assert_eq!(rate_factor(2 * half), power);
            assert_eq!(rate_factor(2 * half + 1), FRAC_1_SQRT_2 * power);
            assert_eq!(
                rate_factor(2 * half + 1) * f64::from(1u32 << half),
                FRAC_1_SQRT_2
            );
        }
        for level in 0..=META_FID_MAX {
            let squared = rate_factor(level) * rate_factor(level) * f64::from(1u32 << level);
            assert!(
                (squared - 1.0).abs() < 4.0 * f64::EPSILON,
                "{level}: {squared}"
            );
        }
        let meta_rate = 8.0 / 8192.0;
        assert_eq!(rate(meta_rate, 0), meta_rate);
        assert_eq!(rate(meta_rate, 2), 4.0 / 8192.0);
        assert_eq!(rate(meta_rate, 16), 8.0 / 8192.0 / 256.0);
        assert_eq!(rate(meta_rate, 1), meta_rate * FRAC_1_SQRT_2);
    }

    /// The price table at the study's 8 192 steps and α = 0.03 (§13.11), and at 0.1 and
    /// 0.01, each entry `max_steps` × 2^(α·f/2) rounded to the nearest integer, read off a
    /// 60-digit decimal reckoning of the same power.
    #[test]
    fn the_price_table_is_the_power_law_rounded() {
        let table = |alpha| (0..=16).map(|f| price(8192, alpha, f)).collect::<Vec<_>>();
        assert_eq!(
            table(0.03),
            [
                8192, 8278, 8364, 8452, 8540, 8629, 8719, 8810, 8903, 8996, 9090, 9185, 9281, 9378,
                9476, 9575, 9675
            ]
        );
        assert_eq!(
            table(0.1),
            [
                8192, 8481, 8780, 9090, 9410, 9742, 10086, 10441, 10809, 11191, 11585, 11994,
                12417, 12855, 13308, 13777, 14263
            ]
        );
        assert_eq!(
            table(0.01),
            [
                8192, 8220, 8249, 8278, 8306, 8335, 8364, 8393, 8422, 8452, 8481, 8510, 8540, 8570,
                8599, 8629, 8659
            ]
        );
    }

    #[test]
    fn the_price_is_the_power_law_at_any_exponent_and_budget() {
        for alpha in [0.0, 0.005, 0.03, 0.25, 0.4, 0.77, 1.0] {
            for max_steps in [1, 7, 8192, 65_536, 1_048_576] {
                for level in 0..=META_FID_MAX {
                    let exact = f64::from(max_steps) * 2f64.powf(alpha * f64::from(level) / 2.0);
                    let read = f64::from(price(max_steps, alpha, level));
                    assert!(
                        (read - exact).abs() <= 0.5 + exact * 1e-9,
                        "{alpha} {max_steps} {level}: {read} against {exact}"
                    );
                }
            }
        }
        assert_eq!(price(8192, 1.0, 16), 8192 * 256);
        assert_eq!(price(8192, 0.5, 4), 8192 * 2);
        assert_eq!(price(u32::MAX, 1.0, 16), u32::MAX);
    }

    #[test]
    fn free_fidelity_and_the_base_level_cost_the_base_price() {
        for level in 0..=META_FID_MAX {
            assert_eq!(price(8192, 0.0, level), 8192);
        }
        for alpha in [0.01, 0.03, 0.4, 1.0] {
            assert_eq!(price(8192, alpha, 0), 8192);
        }
        let params = Params {
            meta_fid_max: 4,
            meta_fid_alpha: 0.03,
            ..Params::default()
        };
        assert_eq!(prices(&params), [8192, 8278, 8364, 8452, 8540]);
    }
}
