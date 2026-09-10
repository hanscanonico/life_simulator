//! World → RGBA pixels. The engine owns the colours: the browser viewer draws what this
//! produces and never invents a palette of its own (`docs/DESIGN.md` §2).

use crate::hash::fnv1a64;

pub const BYTES_PER_PIXEL: usize = 4;

/// Op density at which a soup cell is drawn at full brightness. Uniformly random bytes
/// sit at 10/256 ≈ 0.039, so a fresh soup renders dim and a soup that has filled up with
/// instructions renders bright.
const FULL_BRIGHTNESS_OP_DENSITY: f64 = 0.25;
const MIN_VALUE: f64 = 0.15;
const SATURATION: f64 = 0.85;

/// Hue from a stable hash of the tape, brightness from how much of it is instructions.
pub fn soup_pixel(tape: &[u8], op_density: f64) -> [u8; 4] {
    let hue = (fnv1a64(tape) % 3600) as f64 / 10.0;
    let reach = (op_density / FULL_BRIGHTNESS_OP_DENSITY).clamp(0.0, 1.0);
    let value = MIN_VALUE + (1.0 - MIN_VALUE) * reach;
    let [r, g, b] = hsv_to_rgb(hue, SATURATION, value);
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
        let tape = b"replicate me";
        assert_eq!(soup_pixel(tape, 0.1), soup_pixel(tape, 0.1));
        assert_ne!(soup_pixel(tape, 0.1), soup_pixel(b"something else", 0.1));

        let dim = soup_pixel(tape, 0.0);
        let bright = soup_pixel(tape, 1.0);
        let sum = |p: [u8; 4]| p[0] as u32 + p[1] as u32 + p[2] as u32;
        assert!(sum(bright) > sum(dim));
        assert_eq!(soup_pixel(tape, 1.0), soup_pixel(tape, 0.25), "clamped");
    }

    #[test]
    fn life_cells_are_black_and_white() {
        assert_eq!(life_pixel(true), [255, 255, 255, 255]);
        assert_eq!(life_pixel(false), [0, 0, 0, 255]);
    }
}
