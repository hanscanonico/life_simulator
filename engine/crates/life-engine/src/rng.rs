//! The one random source of the simulation: `xoshiro256**`, seeded from the run seed.
//!
//! Every draw goes through the helpers here rather than through a distribution crate, so
//! the byte stream is identical on native and on wasm32 (`docs/DESIGN.md` §1.1).

use rand_core::{RngCore, SeedableRng};
use rand_xoshiro::Xoshiro256StarStar;

pub type Rng = Xoshiro256StarStar;

/// SplitMix64, used only to spread a `(seed, stream, epoch)` triple over the seed space.
fn mix(mut z: u64) -> u64 {
    z = z.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut x = z;
    x = (x ^ (x >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    x = (x ^ (x >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    x ^ (x >> 31)
}

/// A stream that depends only on `(seed, stream, epoch)`, so a world restored from a
/// snapshot draws exactly what an uninterrupted run would have drawn at that epoch.
pub fn seeded(seed: u64, stream: u64, epoch: u64) -> Rng {
    Rng::seed_from_u64(mix(
        seed ^ mix(stream.wrapping_mul(0x2545_F491_4F6C_DD1D) ^ epoch)
    ))
}

/// Uniform in `0..n`, by rejection so that no value is favoured. `n` must be non-zero.
pub fn below(rng: &mut Rng, n: u64) -> u64 {
    debug_assert!(n > 0);
    if n == 1 {
        return 0;
    }
    let zone = u64::MAX - (u64::MAX % n) - 1;
    loop {
        let x = rng.next_u64();
        if x <= zone {
            return x % n;
        }
    }
}

/// True with probability `p`, using 53 bits of one draw.
pub fn chance(rng: &mut Rng, p: f64) -> bool {
    const SCALE: f64 = 1.0 / (1u64 << 53) as f64;
    ((rng.next_u64() >> 11) as f64) * SCALE < p
}

pub fn byte(rng: &mut Rng) -> u8 {
    (rng.next_u64() >> 56) as u8
}

/// Fisher–Yates, drawing from `rng` only.
pub fn shuffle<T>(items: &mut [T], rng: &mut Rng) {
    for i in (1..items.len()).rev() {
        let j = below(rng, i as u64 + 1) as usize;
        items.swap(i, j);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn same_seed_gives_the_same_stream() {
        let mut a = seeded(42, 0, 7);
        let mut b = seeded(42, 0, 7);
        let mut c = seeded(42, 0, 8);
        assert_eq!(a.next_u64(), b.next_u64());
        assert_ne!(seeded(42, 0, 7).next_u64(), c.next_u64());
    }

    #[test]
    fn below_stays_in_range_and_covers_it() {
        let mut rng = seeded(1, 0, 0);
        let mut seen = [false; 6];
        for _ in 0..1000 {
            let v = below(&mut rng, 6) as usize;
            seen[v] = true;
        }
        assert!(seen.iter().all(|s| *s));
        assert_eq!(below(&mut rng, 1), 0);
    }

    #[test]
    fn chance_brackets_the_probability() {
        let mut rng = seeded(2, 0, 0);
        assert!(!chance(&mut rng, 0.0));
        assert!(chance(&mut rng, 1.0));
        let hits = (0..10_000).filter(|_| chance(&mut rng, 0.25)).count();
        assert!((2100..2900).contains(&hits), "{hits}");
    }

    #[test]
    fn shuffle_is_a_permutation_and_depends_on_the_stream() {
        let mut a: Vec<u32> = (0..64).collect();
        let mut b = a.clone();
        shuffle(&mut a, &mut seeded(3, 0, 0));
        shuffle(&mut b, &mut seeded(3, 0, 0));
        assert_eq!(a, b);
        assert_ne!(a, (0..64).collect::<Vec<u32>>());
        let mut sorted = a.clone();
        sorted.sort_unstable();
        assert_eq!(sorted, (0..64).collect::<Vec<u32>>());
    }
}
