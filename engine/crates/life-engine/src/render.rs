//! World → RGBA pixels. The engine owns the colours: the browser viewer draws what this
//! produces and never invents a palette of its own (`docs/DESIGN.md` §2).

use crate::bff;
use crate::hash;

pub const BYTES_PER_PIXEL: usize = 4;

/// Op density at which a soup cell is drawn at full brightness and full saturation.
/// Uniformly random bytes sit at 10/256 ≈ 0.039, so a fresh soup renders dark and grey
/// and a soup that has filled up with instructions renders bright and saturated.
const FULL_BRIGHTNESS_OP_DENSITY: f64 = 0.25;
const MIN_VALUE: f64 = 0.06;
const MIN_SATURATION: f64 = 0.2;
const MAX_SATURATION: f64 = 0.95;

/// Hue from the tape's *instruction skeleton* — the sequence of BFF ops with the non-op
/// bytes dropped — so that a family of near-identical replicators shares a colour and a
/// colony reads as one hue instead of noise. Two tapes that differ only in bytes the
/// interpreter ignores are the same programme, and get the same hue.
fn skeleton_hue(tape: &[u8]) -> f64 {
    let mut digest = hash::OFFSET_BASIS;
    for byte in tape {
        if bff::is_op(*byte) {
            digest ^= *byte as u64;
            digest = digest.wrapping_mul(hash::PRIME);
        }
    }
    (digest % 3600) as f64 / 10.0
}

/// Hue from the instruction skeleton, saturation and brightness from how much of the
/// tape is instructions: op-free tapes stay near-black, so random soup is a dark field
/// the colonies pop out of.
pub fn soup_pixel(tape: &[u8], op_density: f64) -> [u8; 4] {
    let hue = skeleton_hue(tape);
    let reach = (op_density / FULL_BRIGHTNESS_OP_DENSITY).clamp(0.0, 1.0);
    let saturation = MIN_SATURATION + (MAX_SATURATION - MIN_SATURATION) * reach;
    let value = MIN_VALUE + (1.0 - MIN_VALUE) * reach;
    let [r, g, b] = hsv_to_rgb(hue, saturation, value);
    [r, g, b, 255]
}

pub fn life_pixel(alive: bool) -> [u8; 4] {
    if alive {
        [255, 255, 255, 255]
    } else {
        [0, 0, 0, 255]
    }
}

fn hsv_to_rgb(hue: f64, saturation: f64, value: f64) -> [u8; 3] {
    let sector = (hue / 60.0).rem_euclid(6.0);
    let chroma = value * saturation;
    let second = chroma * (1.0 - (sector % 2.0 - 1.0).abs());
    let (r, g, b) = match sector as u32 {
        0 => (chroma, second, 0.0),
        1 => (second, chroma, 0.0),
        2 => (0.0, chroma, second),
        3 => (0.0, second, chroma),
        4 => (second, 0.0, chroma),
        _ => (chroma, 0.0, second),
    };
    let base = value - chroma;
    [
        (((r + base) * 255.0).round()) as u8,
        (((g + base) * 255.0).round()) as u8,
        (((b + base) * 255.0).round()) as u8,
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn primaries_round_trip_through_hsv() {
        assert_eq!(hsv_to_rgb(0.0, 1.0, 1.0), [255, 0, 0]);
        assert_eq!(hsv_to_rgb(120.0, 1.0, 1.0), [0, 255, 0]);
        assert_eq!(hsv_to_rgb(240.0, 1.0, 1.0), [0, 0, 255]);
        assert_eq!(hsv_to_rgb(0.0, 0.0, 1.0), [255, 255, 255]);
        assert_eq!(hsv_to_rgb(0.0, 0.0, 0.0), [0, 0, 0]);
    }

    #[test]
    fn a_tapes_hue_is_stable_and_its_brightness_follows_op_density() {
        let tape = b"re+pli-cate.me";
        assert_eq!(soup_pixel(tape, 0.1), soup_pixel(tape, 0.1));

        let dim = soup_pixel(tape, 0.0);
        let bright = soup_pixel(tape, 1.0);
        let sum = |p: [u8; 4]| p[0] as u32 + p[1] as u32 + p[2] as u32;
        assert!(sum(bright) > sum(dim));
        assert_eq!(soup_pixel(tape, 1.0), soup_pixel(tape, 0.25), "clamped");
    }

    #[test]
    fn tapes_differing_only_in_non_op_bytes_share_a_hue() {
        let one = b"aa+bb[cc]dd-ee";
        let other = b"zz+ZZ[qq]QQ-ww";
        assert_eq!(skeleton_hue(one), skeleton_hue(other));
        assert_eq!(soup_pixel(one, 0.3), soup_pixel(other, 0.3), "same colour");
    }

    #[test]
    fn a_different_instruction_sequence_gets_a_different_hue() {
        assert_ne!(
            skeleton_hue(b"aa+bb[cc]dd-ee"),
            skeleton_hue(b"aa-bb[cc]dd+ee")
        );
        assert_ne!(skeleton_hue(b"+[.]"), skeleton_hue(b"+[.].."));
    }

    #[test]
    fn an_op_free_tape_is_near_black() {
        let pixel = soup_pixel(b"no instructions here", 0.0);
        assert!(
            pixel[0..3].iter().all(|c| *c < 20),
            "op-free soup stays dark: {pixel:?}"
        );
        assert_eq!(pixel[3], 255);
    }

    #[test]
    fn life_cells_are_black_and_white() {
        assert_eq!(life_pixel(true), [255, 255, 255, 255]);
        assert_eq!(life_pixel(false), [0, 0, 0, 255]);
    }
}
