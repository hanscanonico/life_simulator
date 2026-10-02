//! Tapes as the readings name them: parsed from the command line, shown, and compared.

use life_engine::bff;

/// A generic no-op byte: no op, not the emit, not the NAND, not zero.
pub const FILLER: u8 = 0x80;

/// The 14 symbols the substitution searches write: the ten ops, the emit, the NAND, a zero
/// and a generic no-op — the design study's restricted alphabet (`docs/studies/meta-stack.md`
/// §2.4, §7.3), and the 14 kinds of byte `meta_draw: isa` draws.
pub const ALPHABET: [u8; 14] = [
    b'<',
    b'>',
    b'{',
    b'}',
    b'+',
    b'-',
    b'.',
    b',',
    b'[',
    b']',
    bff::EMIT,
    bff::NAND,
    0,
    FILLER,
];

/// A tape from its spelling: `hex:` and two hex digits a byte, or the shown form, where an
/// op, `!` and `~` stand for themselves, `0` for a zero and `·` or `_` for `FILLER`. A tape
/// shorter than `len` is padded with zeros to it.
pub fn parse(spec: &str, len: usize) -> Result<Vec<u8>, String> {
    let mut tape = match spec.strip_prefix("hex:") {
        Some(digits) => parse_hex(digits)?,
        None => spec
            .chars()
            .map(|c| match c {
                '·' | '_' => Ok(FILLER),
                '0' => Ok(0),
                c if c.is_ascii() && shown_as_itself(c as u8) => Ok(c as u8),
                c => Err(format!(
                    "{c:?} is no symbol of a shown tape; spell it in hex:"
                )),
            })
            .collect::<Result<Vec<u8>, String>>()?,
    };
    if tape.len() < len {
        tape.resize(len, 0);
    }
    Ok(tape)
}

fn parse_hex(digits: &str) -> Result<Vec<u8>, String> {
    if !digits.len().is_multiple_of(2) {
        return Err("a hex tape needs two digits a byte".into());
    }
    (0..digits.len())
        .step_by(2)
        .map(|at| {
            u8::from_str_radix(&digits[at..at + 2], 16)
                .map_err(|_| format!("{:?} is not a hex byte", &digits[at..at + 2]))
        })
        .collect()
}

fn shown_as_itself(byte: u8) -> bool {
    bff::is_op(byte) || byte == bff::EMIT || byte == bff::NAND
}

/// The shown form: lossy, every other nonzero byte reads `·`.
pub fn show(tape: &[u8]) -> String {
    tape.iter()
        .map(|byte| match *byte {
            byte if shown_as_itself(byte) => byte as char,
            0 => '0',
            _ => '·',
        })
        .collect()
}

pub fn hex(tape: &[u8]) -> String {
    let digits: String = tape.iter().map(|byte| format!("{byte:02x}")).collect();
    format!("hex:{digits}")
}

/// The substitution distance between two tapes of one length, `None` across lengths.
pub fn hamming(a: &[u8], b: &[u8]) -> Option<usize> {
    (a.len() == b.len()).then(|| a.iter().zip(b).filter(|(x, y)| x != y).count())
}

/// The edit distance (substitutions, insertions, deletions), for tapes of different lengths.
pub fn levenshtein(a: &[u8], b: &[u8]) -> usize {
    let mut row: Vec<usize> = (0..=b.len()).collect();
    for (i, x) in a.iter().enumerate() {
        let mut diagonal = row[0];
        row[0] = i + 1;
        for (j, y) in b.iter().enumerate() {
            let above = row[j + 1];
            row[j + 1] = (above + 1)
                .min(row[j] + 1)
                .min(diagonal + usize::from(x != y));
            diagonal = above;
        }
    }
    row[b.len()]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_shown_tape_reads_back_and_pads_with_zeros() {
        let tape = parse("<{~!·_0", 10).unwrap();
        assert_eq!(tape, [b'<', b'{', b'~', b'!', FILLER, FILLER, 0, 0, 0, 0]);
        assert_eq!(show(&tape), "<{~!··0000");
    }

    #[test]
    fn a_hex_tape_reads_back_exactly() {
        let tape = vec![0x3c, 0x7e, 0x21, 0x5a, 0x00];
        assert_eq!(parse(&hex(&tape), 0).unwrap(), tape);
        assert!(parse("hex:3c7", 0).is_err());
        assert!(parse("hex:zz", 0).is_err());
        assert!(parse("<Z!", 0).is_err());
    }

    #[test]
    fn the_distances_count_what_differs() {
        let a = parse("<<{~~{{>>~{~!", 32).unwrap();
        assert_eq!(hamming(&a, &a), Some(0));
        let mut b = a.clone();
        b[9] = FILLER;
        assert_eq!(hamming(&a, &b), Some(1));
        assert_eq!(hamming(&a, &a[..31]), None);
        assert_eq!(levenshtein(&a, &a), 0);
        assert_eq!(levenshtein(&a, &b), 1);
        assert_eq!(levenshtein(b"<{~!", b"<<{~!"), 1);
        assert_eq!(levenshtein(b"", b"<!"), 2);
    }
}
