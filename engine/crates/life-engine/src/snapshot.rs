//! The snapshot container: a small header plus the zlib-compressed cell bytes and, since
//! version 3, the zlib-compressed lineage tags beside them. Rails stores these verbatim,
//! so the header carries enough to reject a mismatched restore.
//!
//! Version 3 layout: `MAGIC`, version, substrate, width, height, tape_len, epoch, the
//! four transition fields, then the length of the cell payload as a `u64` — the two
//! payloads follow back to back, cells first.

use crate::metrics::{self, TransitionState};
use crate::params::{Params, Substrate};
use flate2::read::ZlibDecoder;
use std::fmt;
use std::io::Read;

pub const MAGIC: [u8; 4] = *b"LSNP";
pub const VERSION: u8 = 3;
pub const HEADER_LEN: usize = 62;
/// Version 2 carried tapes only, version 1 not even the transition tracker; Postgres
/// still holds both, and every run they belong to must stay resumable.
const HEADER_LEN_V2: usize = 54;
const HEADER_LEN_V1: usize = 26;
const LINEAGE_BYTES: usize = 8;
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

/// What a blob restores: the header, the cells, and the lineage tags a version 3 blob
/// carries. `lineages` is `None` for the older formats, which held no ancestry — the
/// caller mints a fresh census there rather than inventing one here.
pub struct Restored {
    pub header: Header,
    pub cells: Vec<u8>,
    pub lineages: Option<Vec<u64>>,
}

fn epoch_field(epoch: Option<u64>) -> i64 {
    epoch.map_or(NO_EPOCH, |epoch| epoch as i64)
}

fn epoch_from_field(field: i64) -> Option<u64> {
    (field >= 0).then_some(field as u64)
}

pub fn encode(header: &Header, cells: &[u8], lineages: &[u64]) -> Vec<u8> {
    encode_compressed(header, &metrics::compress(cells), lineages)
}

/// A snapshot built from a cell payload already compressed by `compress` — the header and
/// the lineage payload bracket it unchanged, so a caller that needs the payload's length
/// for `compress_ratio` can compress the cells once and still produce the very same
/// snapshot bytes.
pub fn encode_compressed(header: &Header, payload: &[u8], lineages: &[u64]) -> Vec<u8> {
    let tags = metrics::compress(&lineage_bytes(lineages));
    let mut out = Vec::with_capacity(HEADER_LEN + payload.len() + tags.len());
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
    out.extend_from_slice(&(payload.len() as u64).to_le_bytes());
    out.extend_from_slice(payload);
    out.extend_from_slice(&tags);
    out
}

fn lineage_bytes(lineages: &[u64]) -> Vec<u8> {
    let mut out = Vec::with_capacity(lineages.len() * LINEAGE_BYTES);
    for id in lineages {
        out.extend_from_slice(&id.to_le_bytes());
    }
    out
}

/// How many bytes of lineage tags the params describe: one `u64` per cell in the soup,
/// none in life, which carries no ancestry.
fn expected_lineage_bytes(params: &Params) -> usize {
    match params.substrate {
        Substrate::Soup => params.cell_count() * LINEAGE_BYTES,
        Substrate::Life => 0,
    }
}

fn lineages_from(bytes: &[u8]) -> Vec<u64> {
    let (ids, _) = bytes.as_chunks::<LINEAGE_BYTES>();
    ids.iter().copied().map(u64::from_le_bytes).collect()
}

/// Inflates a payload one byte past the world the params describe: enough to tell "too
/// long" from "exactly right", so a corrupt blob can no longer inflate a resuming slot off
/// the box. The buffer holds that extra byte from the start, so `read_to_end` reaches the
/// limit without doubling the world-sized allocation it began with.
fn inflate_bounded(payload: &[u8], expected: usize) -> Result<Vec<u8>, SnapshotError> {
    let mut cells = Vec::with_capacity(expected + 1);
    ZlibDecoder::new(payload)
        .take(expected as u64 + 1)
        .read_to_end(&mut cells)
        .map_err(SnapshotError::Corrupt)?;
    Ok(cells)
}

/// Reads a snapshot back, checking it describes the world `params` describes.
pub fn decode(params: &Params, bytes: &[u8]) -> Result<Restored, SnapshotError> {
    if bytes.len() < HEADER_LEN_V1 {
        return Err(SnapshotError::Truncated);
    }
    if bytes[..4] != MAGIC {
        return Err(SnapshotError::BadMagic);
    }
    let header_len = match bytes[4] {
        1 => HEADER_LEN_V1,
        2 => HEADER_LEN_V2,
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
    let transition = if header_len > HEADER_LEN_V1 {
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

    let (cell_payload, lineage_payload) = if header_len == HEADER_LEN {
        let payload_len = u64::from_le_bytes(bytes[54..62].try_into().expect("eight bytes"));
        let rest = &bytes[header_len..];
        let payload_len = usize::try_from(payload_len).map_err(|_| SnapshotError::Truncated)?;
        if rest.len() < payload_len {
            return Err(SnapshotError::Truncated);
        }
        let (cells, tags) = rest.split_at(payload_len);
        (cells, Some(tags))
    } else {
        (&bytes[header_len..], None)
    };

    let expected = params.cell_count() * params.stride();
    let cells = inflate_bounded(cell_payload, expected)?;
    if cells.len() != expected {
        return Err(SnapshotError::Mismatch {
            field: "cell count",
        });
    }

    let lineages = lineage_payload
        .map(|payload| decode_lineages(params, payload))
        .transpose()?;
    Ok(Restored {
        header,
        cells,
        lineages,
    })
}

fn decode_lineages(params: &Params, payload: &[u8]) -> Result<Vec<u64>, SnapshotError> {
    let expected = expected_lineage_bytes(params);
    let tags = inflate_bounded(payload, expected)?;
    if tags.len() != expected {
        return Err(SnapshotError::Mismatch {
            field: "lineage count",
        });
    }
    Ok(lineages_from(&tags))
}

/// Blobs in the formats Postgres still holds, written the way the engine wrote them
/// before lineage tags — every module that has to keep reading them tests against these.
#[cfg(test)]
pub(crate) mod legacy {
    use super::*;

    /// A snapshot as the first released engine wrote it: the 26-byte header, version 1.
    pub(crate) fn v1_blob(params: &Params, epoch: u64, cells: &[u8]) -> Vec<u8> {
        let mut out = prefix(params, 1, epoch);
        out.extend_from_slice(&metrics::compress(cells));
        out
    }

    /// A snapshot as the engine wrote it before lineage tags: the 54-byte header, version
    /// 2, the transition tracker and the cell payload, and nothing after it.
    pub(crate) fn v2_blob(
        params: &Params,
        epoch: u64,
        transition: TransitionState,
        cells: &[u8],
    ) -> Vec<u8> {
        let mut out = prefix(params, 2, epoch);
        out.extend_from_slice(&epoch_field(transition.candidate).to_le_bytes());
        out.extend_from_slice(&transition.held.to_le_bytes());
        out.extend_from_slice(&epoch_field(transition.settled).to_le_bytes());
        out.extend_from_slice(&epoch_field(transition.last_epoch).to_le_bytes());
        assert_eq!(out.len(), HEADER_LEN_V2);
        out.extend_from_slice(&metrics::compress(cells));
        out
    }

    fn prefix(params: &Params, version: u8, epoch: u64) -> Vec<u8> {
        let mut out = Vec::new();
        out.extend_from_slice(&MAGIC);
        out.push(version);
        out.push(match params.substrate {
            Substrate::Soup => 0,
            Substrate::Life => 1,
        });
        out.extend_from_slice(&params.width.to_le_bytes());
        out.extend_from_slice(&params.height.to_le_bytes());
        out.extend_from_slice(&params.tape_len.to_le_bytes());
        out.extend_from_slice(&epoch.to_le_bytes());
        assert_eq!(out.len(), HEADER_LEN_V1);
        out
    }
}

#[cfg(test)]
mod tests {
    use super::legacy::{v1_blob, v2_blob};
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

    fn lineages(params: &Params) -> Vec<u64> {
        (0..params.cell_count() as u64).map(|id| id * 3).collect()
    }

    #[test]
    fn round_trips_cells_and_epoch() {
        let params = params();
        let cells: Vec<u8> = (0..128).map(|i| i as u8).collect();
        let bytes = encode(&header(&params, 99), &cells, &lineages(&params));
        assert!(bytes.len() < cells.len() + HEADER_LEN + 64);

        let restored = decode(&params, &bytes).unwrap();
        assert_eq!(restored.cells, cells);
        assert_eq!(restored.header.epoch, 99);
        assert_eq!(restored.header.width, 4);
    }

    #[test]
    fn round_trips_the_lineage_tags() {
        let params = params();
        let cells = vec![7u8; 128];
        let tags = lineages(&params);

        let bytes = encode(&header(&params, 3), &cells, &tags);

        assert_eq!(decode(&params, &bytes).unwrap().lineages, Some(tags));
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
            &lineages(&params),
        );

        let restored = decode(&params, &bytes).unwrap();
        assert_eq!(restored.header.transition, transition);
    }

    #[test]
    fn version_one_blobs_still_decode_with_a_fresh_tracker() {
        let params = params();
        let cells: Vec<u8> = (0..128).map(|i| i as u8).collect();

        let restored = decode(&params, &v1_blob(&params, 7, &cells)).unwrap();
        assert_eq!(restored.cells, cells);
        assert_eq!(restored.header.epoch, 7);
        assert_eq!(restored.header.transition, TransitionState::default());
        assert_eq!(restored.lineages, None);
    }

    #[test]
    fn version_two_blobs_still_decode_with_their_tracker_and_no_lineages() {
        let params = params();
        let cells: Vec<u8> = (0..128).map(|i| i as u8).collect();
        let transition = TransitionState {
            candidate: Some(12),
            held: 1,
            settled: None,
            last_epoch: Some(20),
        };

        let restored = decode(&params, &v2_blob(&params, 20, transition, &cells)).unwrap();
        assert_eq!(restored.cells, cells);
        assert_eq!(restored.header.epoch, 20);
        assert_eq!(restored.header.transition, transition);
        assert_eq!(restored.lineages, None);
    }

    #[test]
    fn an_inflating_payload_is_never_buffered_past_the_world_plus_a_byte() {
        let expected = 64 * 1024;
        let payload = metrics::compress(&vec![0u8; expected * 8]);

        let cells = inflate_bounded(&payload, expected).expect("a well-formed zlib stream");

        assert_eq!(cells.len(), expected + 1);
        assert!(
            cells.capacity() <= expected + 1,
            "buffered {} bytes for a {expected}-byte world",
            cells.capacity()
        );
    }

    #[test]
    fn rejects_a_payload_that_inflates_past_the_world() {
        let params = params();
        let expected = params.cell_count() * params.stride();
        let bytes = encode(
            &header(&params, 0),
            &vec![0u8; expected * 8],
            &lineages(&params),
        );

        assert!(matches!(
            decode(&params, &bytes),
            Err(SnapshotError::Mismatch {
                field: "cell count"
            })
        ));
    }

    #[test]
    fn rejects_lineage_tags_that_do_not_count_the_cells() {
        let params = params();
        let cells = vec![0u8; 128];
        let bytes = encode(&header(&params, 0), &cells, &vec![0u64; 128]);

        assert!(matches!(
            decode(&params, &bytes),
            Err(SnapshotError::Mismatch {
                field: "lineage count"
            })
        ));
    }

    #[test]
    fn rejects_a_cell_payload_length_the_blob_cannot_hold() {
        let params = params();
        let mut bytes = encode(&header(&params, 0), &[0u8; 128], &lineages(&params));
        let overrun = (bytes.len() as u64).to_le_bytes();
        bytes[HEADER_LEN_V2..HEADER_LEN].copy_from_slice(&overrun);

        assert!(matches!(
            decode(&params, &bytes),
            Err(SnapshotError::Truncated)
        ));
    }

    #[test]
    fn rejects_snapshots_that_do_not_fit_the_params() {
        let params = params();
        let cells = vec![0u8; 128];
        let bytes = encode(&header(&params, 0), &cells, &lineages(&params));

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
        future[4] = 4;
        assert!(matches!(
            decode(&params, &future),
            Err(SnapshotError::UnsupportedVersion(4))
        ));
    }
}
