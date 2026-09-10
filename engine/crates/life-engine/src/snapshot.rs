//! The snapshot container: a small header plus the zlib-compressed cell bytes. Rails
//! stores these verbatim, so the header carries enough to reject a mismatched restore.

use crate::params::{Params, Substrate};
use flate2::read::ZlibDecoder;
use flate2::write::ZlibEncoder;
use flate2::Compression;
use std::fmt;
use std::io::{Read, Write};

pub const MAGIC: [u8; 4] = *b"LSNP";
pub const VERSION: u8 = 1;
pub const HEADER_LEN: usize = 26;

#[derive(Debug)]
pub enum SnapshotError {
    Truncated,
    BadMagic,
    UnsupportedVersion(u8),
    Mismatch { field: &'static str },
    Corrupt(std::io::Error),
}

impl fmt::Display for SnapshotError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Truncated => write!(f, "snapshot is shorter than its header"),
            Self::BadMagic => write!(f, "not a snapshot"),
            Self::UnsupportedVersion(v) => write!(f, "unsupported snapshot version {v}"),
            Self::Mismatch { field } => write!(f, "snapshot {field} does not match the params"),
            Self::Corrupt(e) => write!(f, "snapshot payload is corrupt: {e}"),
        }
    }
}

impl std::error::Error for SnapshotError {}

pub struct Header {
    pub substrate: Substrate,
    pub width: u32,
    pub height: u32,
    pub tape_len: u32,
    pub epoch: u64,
}

pub fn encode(header: &Header, cells: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(HEADER_LEN + cells.len() / 4);
    out.extend_from_slice(&MAGIC);
    out.push(VERSION);
    out.push(match header.substrate {
        Substrate::Soup => 0,
        Substrate::Life => 1,
    });
    out.extend_from_slice(&header.width.to_le_bytes());
    out.extend_from_slice(&header.height.to_le_bytes());
    out.extend_from_slice(&header.tape_len.to_le_bytes());
    out.extend_from_slice(&header.epoch.to_le_bytes());

    let mut encoder = ZlibEncoder::new(out, Compression::default());
    encoder
        .write_all(cells)
        .expect("writing to a Vec cannot fail");
    encoder.finish().expect("writing to a Vec cannot fail")
}

/// Reads a snapshot back, checking it describes the world `params` describes.
pub fn decode(params: &Params, bytes: &[u8]) -> Result<(Header, Vec<u8>), SnapshotError> {
    if bytes.len() < HEADER_LEN {
        return Err(SnapshotError::Truncated);
    }
    if bytes[..4] != MAGIC {
        return Err(SnapshotError::BadMagic);
    }
    if bytes[4] != VERSION {
        return Err(SnapshotError::UnsupportedVersion(bytes[4]));
    }
    let substrate = match bytes[5] {
        0 => Substrate::Soup,
        1 => Substrate::Life,
        _ => return Err(SnapshotError::Mismatch { field: "substrate" }),
    };
    let word =
        |at: usize| u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]]);
    let header = Header {
        substrate,
        width: word(6),
        height: word(10),
        tape_len: word(14),
        epoch: u64::from_le_bytes(bytes[18..26].try_into().expect("eight bytes")),
    };

    if header.substrate != params.substrate {
        return Err(SnapshotError::Mismatch { field: "substrate" });
    }
    if header.width != params.width {
        return Err(SnapshotError::Mismatch { field: "width" });
    }
    if header.height != params.height {
        return Err(SnapshotError::Mismatch { field: "height" });
    }
    if header.tape_len != params.tape_len {
        return Err(SnapshotError::Mismatch { field: "tape_len" });
    }

    let mut cells = Vec::new();
    ZlibDecoder::new(&bytes[HEADER_LEN..])
        .read_to_end(&mut cells)
        .map_err(SnapshotError::Corrupt)?;
    if cells.len() != params.cell_count() * params.stride() {
        return Err(SnapshotError::Mismatch {
            field: "cell count",
        });
    }
    Ok((header, cells))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn params() -> Params {
        Params {
            width: 4,
            height: 4,
            tape_len: 8,
            ..Params::default()
        }
    }

    fn header(params: &Params, epoch: u64) -> Header {
        Header {
            substrate: params.substrate,
            width: params.width,
            height: params.height,
            tape_len: params.tape_len,
            epoch,
        }
    }

    #[test]
    fn round_trips_cells_and_epoch() {
        let params = params();
        let cells: Vec<u8> = (0..128).map(|i| i as u8).collect();
        let bytes = encode(&header(&params, 99), &cells);
        assert!(bytes.len() < cells.len() + HEADER_LEN + 32);

        let (header, decoded) = decode(&params, &bytes).unwrap();
        assert_eq!(decoded, cells);
        assert_eq!(header.epoch, 99);
        assert_eq!(header.width, 4);
    }

    #[test]
    fn rejects_snapshots_that_do_not_fit_the_params() {
        let params = params();
        let cells = vec![0u8; 128];
        let bytes = encode(&header(&params, 0), &cells);

        let other = Params {
            width: 8,
            ..params.clone()
        };
        assert!(matches!(
            decode(&other, &bytes),
            Err(SnapshotError::Mismatch { field: "width" })
        ));
        assert!(matches!(
            decode(&params, &bytes[..10]),
            Err(SnapshotError::Truncated)
        ));
        assert!(matches!(
            decode(&params, &[b'x'; 64]),
            Err(SnapshotError::BadMagic)
        ));
    }
}
