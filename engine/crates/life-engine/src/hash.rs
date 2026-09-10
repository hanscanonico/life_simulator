//! FNV-1a, the one hash the engine uses. It is spelled out here rather than taken from
//! `std` because both the determinism tests and the viewer's colours depend on the exact
//! value, on every platform and every build.

pub const OFFSET_BASIS: u64 = 0xcbf2_9ce4_8422_2325;
pub const PRIME: u64 = 0x0000_0100_0000_01b3;

pub fn fnv1a64(bytes: &[u8]) -> u64 {
    let mut hash = OFFSET_BASIS;
    for byte in bytes {
        hash ^= *byte as u64;
        hash = hash.wrapping_mul(PRIME);
    }
    hash
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_the_published_vectors() {
        assert_eq!(fnv1a64(b""), OFFSET_BASIS);
        assert_eq!(fnv1a64(b"a"), 0xaf63_dc4c_8601_ec8c);
        assert_eq!(fnv1a64(b"foobar"), 0x8594_4171_f739_67e8);
    }
}
