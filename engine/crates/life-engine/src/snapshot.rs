//! The snapshot container: a small header plus the zlib-compressed cell bytes. Rails
//! stores these verbatim, so the header carries enough to reject a mismatched restore.

use crate::metrics::{self, TransitionState};
use crate::params::{Params, Substrate};
use flate2::read::ZlibDecoder;
use std::fmt;
use std::io::Read;

pub const MAGIC: [u8; 4] = *b"LSNP";
pub const VERSION: u8 = 2;
pub const HEADER_LEN: usize = 54;
/// Version 1 carried no transition tracker; Postgres still holds those blobs and every
/// run they belong to must stay resumable.
const HEADER_LEN_V1: usize = 26;
const NO_EPOCH: i64 = -1;

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
    pub transition: TransitionState,
}

fn epoch_field(epoch: Option<u64>) -> i64 {
    epoch.map_or(NO_EPOCH, |epoch| epoch as i64)
}

fn epoch_from_field(field: i64) -> Option<u64> {
    (field >= 0).then_some(field as u64)
}

pub fn encode(header: &Header, cells: &[u8]) -> Vec<u8> {
    encode_compressed(header, &metrics::compress(cells))
}

/// A snapshot built from a payload already compressed by `compress` — the header is a
/// plain prefix, so a caller that needs the payload's length for `compress_ratio` can
/// compress the cells once and still produce the very same snapshot bytes.
pub fn encode_compressed(header: &Header, payload: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(HEADER_LEN + payload.len());
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
    out.extend_from_slice(&epoch_field(header.transition.candidate).to_le_bytes());
    out.extend_from_slice(&header.transition.held.to_le_bytes());
    out.extend_from_slice(&epoch_field(header.transition.settled).to_le_bytes());
    out.extend_from_slice(&epoch_field(header.transition.last_epoch).to_le_bytes());
    out.extend_from_slice(payload);
    out
}

/// Reads a snapshot back, checking it describes the world `params` describes.
pub fn decode(params: &Params, bytes: &[u8]) -> Result<(Header, Vec<u8>), SnapshotError> {
    if bytes.len() < HEADER_LEN_V1 {
        return Err(SnapshotError::Truncated);
    }
    if bytes[..4] != MAGIC {
        return Err(SnapshotError::BadMagic);
    }
    let header_len = match bytes[4] {
        1 => HEADER_LEN_V1,
        VERSION => HEADER_LEN,
        version => return Err(SnapshotError::UnsupportedVersion(version)),
    };
    if bytes.len() < header_len {
        return Err(SnapshotError::Truncated);
    }
    let substrate = match bytes[5] {
        0 => Substrate::Soup,
        1 => Substrate::Life,
        _ => return Err(SnapshotError::Mismatch { field: "substrate" }),
    };
    let word =
        |at: usize| u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]]);
    let signed = |at: usize| i64::from_le_bytes(bytes[at..at + 8].try_into().expect("eight bytes"));
    let transition = if header_len == HEADER_LEN {
        TransitionState {
            candidate: epoch_from_field(signed(26)),
            held: word(34),
            settled: epoch_from_field(signed(38)),
            last_epoch: epoch_from_field(signed(46)),
        }
    } else {
        TransitionState::default()
    };
    let header = Header {
        substrate,
        width: word(6),
        height: word(10),
        tape_len: word(14),
        epoch: u64::from_le_bytes(bytes[18..26].try_into().expect("eight bytes")),
        transition,
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

    // Read one byte past the world the params describe: enough to tell "too long" from
    // "exactly right", and a corrupt blob can no longer inflate a resuming slot off the box.
    let expected = params.cell_count() * params.stride();
    let mut cells = Vec::with_capacity(expected);
    ZlibDecoder::new(&bytes[header_len..])
        .take(expected as u64 + 1)
        .read_to_end(&mut cells)
        .map_err(SnapshotError::Corrupt)?;
    if cells.len() != expected {
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
            transition: TransitionState::default(),
        }
    }

    /// A snapshot as the first released engine wrote it: the 26-byte header, version 1.
    fn v1_blob(params: &Params, epoch: u64, cells: &[u8]) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&MAGIC);
        out.push(1);
        out.push(0);
        out.extend_from_slice(&params.width.to_le_bytes());
        out.extend_from_slice(&params.height.to_le_bytes());
        out.extend_from_slice(&params.tape_len.to_le_bytes());
        out.extend_from_slice(&epoch.to_le_bytes());
        out.extend_from_slice(&metrics::compress(cells));
        out
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
    fn round_trips_the_transition_tracker() {
        let params = params();
        let cells = vec![0u8; 128];
        let transition = TransitionState {
            candidate: Some(400),
            held: 2,
            settled: Some(400),
            last_epoch: Some(500),
        };
        let bytes = encode(
            &Header {
                transition,
                ..header(&params, 500)
            },
            &cells,
        );

        let (header, _) = decode(&params, &bytes).unwrap();
        assert_eq!(header.transition, transition);
    }

    #[test]
    fn version_one_blobs_still_decode_with_a_fresh_tracker() {
        let params = params();
        let cells: Vec<u8> = (0..128).map(|i| i as u8).collect();

        let (header, decoded) = decode(&params, &v1_blob(&params, 7, &cells)).unwrap();
        assert_eq!(decoded, cells);
        assert_eq!(header.epoch, 7);
        assert_eq!(header.transition, TransitionState::default());
    }

    #[test]
    fn rejects_a_payload_that_inflates_past_the_world() {
        let params = params();
        let expected = params.cell_count() * params.stride();
        let bytes = encode(&header(&params, 0), &vec![0u8; expected * 8]);

        assert!(matches!(
            decode(&params, &bytes),
            Err(SnapshotError::Mismatch {
                field: "cell count"
            })
        ));
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

        let mut future = bytes.clone();
        future[4] = 3;
        assert!(matches!(
            decode(&params, &future),
            Err(SnapshotError::UnsupportedVersion(3))
        ));
    }
}
