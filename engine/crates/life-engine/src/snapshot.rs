//! The snapshot container: a small header plus the zlib-compressed cell bytes and, since
//! version 3, the zlib-compressed lineage tags beside them. Rails stores these verbatim,
//! so the header carries enough to reject a mismatched restore.
//!
//! Version 3 layout: `MAGIC`, version, substrate, width, height, tape_len, epoch, the
//! four transition fields, then the length of the cell payload as a `u64` — the two
//! payloads follow back to back, cells first.
//!
//! Version 4 is what a world whose tapes can grow (DESIGN §1.3, sweep 8) writes: the same
//! header with the lineage payload's length and the tape cap after the cell payload's
//! length, and a third payload holding one live tape length per cell. Its cell payload is
//! the ragged live bytes end to end rather than the padded slots. A world that cannot grow
//! writes version 3, byte for byte as it always did.
//!
//! Version 5 is what a world whose cells hold an energy stock (DESIGN §1.1) writes: the
//! version 4 header with the live-length payload's own length after the tape cap, and a
//! fourth payload holding one stock reading per cell. Its length payload is empty where
//! the tapes cannot grow, so a stocked world of fixed-length tapes and one of growing
//! tapes are the same container. A world with no influx writes version 3 or 4 as before.

use crate::metrics::{self, TransitionState};
use crate::params::{Params, Substrate};
use flate2::read::ZlibDecoder;
use std::fmt;
use std::io::Read;

pub const MAGIC: [u8; 4] = *b"LSNP";
pub const VERSION: u8 = 3;
/// The version a world whose tapes can grow writes; it carries the lengths.
pub const VERSION_RAGGED: u8 = 4;
/// The version a world whose cells hold energy writes; it carries the stocks.
pub const VERSION_STOCKED: u8 = 5;
pub const HEADER_LEN: usize = 62;
const HEADER_LEN_V4: usize = 74;
const HEADER_LEN_V5: usize = 82;
/// Version 2 carried tapes only, version 1 not even the transition tracker; Postgres
/// still holds both, and every run they belong to must stay resumable.
const HEADER_LEN_V2: usize = 54;
const HEADER_LEN_V1: usize = 26;
const LINEAGE_BYTES: usize = 8;
const WORD_BYTES: usize = 4;
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
    /// The longest a tape of this world may be — `Params::tape_cap`. Only a version 4
    /// container carries it; the older ones predate growth, so restoring one reads the
    /// fixed length back as the cap.
    pub tape_cap: u32,
    pub epoch: u64,
    pub transition: TransitionState,
}

/// What a blob restores: the header, the cells as the flat array of `stride`-wide slots
/// the world holds them in, the lineage tags a version 3 blob carries, and the live tape
/// lengths a version 4 blob carries. `lineages` is `None` for the older formats, which
/// held no ancestry — the caller mints a fresh census there rather than inventing one
/// here — and `lens` is `None` wherever every tape fills its slot. `stock` is `None` for
/// every format written before cells held energy.
pub struct Restored {
    pub header: Header,
    pub cells: Vec<u8>,
    pub lineages: Option<Vec<u64>>,
    pub lens: Option<Vec<u32>>,
    pub stock: Option<Vec<u32>>,
}

fn epoch_field(epoch: Option<u64>) -> i64 {
    epoch.map_or(NO_EPOCH, |epoch| epoch as i64)
}

fn epoch_from_field(field: i64) -> Option<u64> {
    (field >= 0).then_some(field as u64)
}

pub fn encode(
    header: &Header,
    cells: &[u8],
    lineages: &[u64],
    lens: &[u32],
    stock: &[u32],
) -> Vec<u8> {
    encode_compressed(header, &metrics::compress(cells), lineages, lens, stock)
}

/// A snapshot built from a cell payload already compressed by `compress` — the header and
/// the lineage payload bracket it unchanged, so a caller that needs the payload's length
/// for `compress_ratio` can compress the cells once and still produce the very same
/// snapshot bytes.
pub fn encode_compressed(
    header: &Header,
    payload: &[u8],
    lineages: &[u64],
    lens: &[u32],
    stock: &[u32],
) -> Vec<u8> {
    let tags = metrics::compress(&lineage_bytes(lineages));
    let stocked = !stock.is_empty();
    let ragged = stocked || !lens.is_empty();
    // A stocked world of fixed-length tapes writes the length payload empty rather than a
    // compressed nothing: the reader tells "no lengths" from "lengths" by that length alone.
    let lengths = match lens.is_empty() {
        true => Vec::new(),
        false => metrics::compress(&word_bytes(lens)),
    };
    let mut out = Vec::with_capacity(HEADER_LEN_V5 + payload.len() + tags.len());
    out.extend_from_slice(&MAGIC);
    out.push(match (stocked, ragged) {
        (true, _) => VERSION_STOCKED,
        (false, true) => VERSION_RAGGED,
        (false, false) => VERSION,
    });
    out.push(substrate_byte(header.substrate));
    out.extend_from_slice(&header.width.to_le_bytes());
    out.extend_from_slice(&header.height.to_le_bytes());
    out.extend_from_slice(&header.tape_len.to_le_bytes());
    out.extend_from_slice(&header.epoch.to_le_bytes());
    out.extend_from_slice(&epoch_field(header.transition.candidate).to_le_bytes());
    out.extend_from_slice(&header.transition.held.to_le_bytes());
    out.extend_from_slice(&epoch_field(header.transition.settled).to_le_bytes());
    out.extend_from_slice(&epoch_field(header.transition.last_epoch).to_le_bytes());
    out.extend_from_slice(&(payload.len() as u64).to_le_bytes());
    if ragged {
        out.extend_from_slice(&(tags.len() as u64).to_le_bytes());
        out.extend_from_slice(&header.tape_cap.to_le_bytes());
    }
    if stocked {
        out.extend_from_slice(&(lengths.len() as u64).to_le_bytes());
    }
    out.extend_from_slice(payload);
    out.extend_from_slice(&tags);
    if ragged {
        out.extend_from_slice(&lengths);
    }
    if stocked {
        out.extend_from_slice(&metrics::compress(&word_bytes(stock)));
    }
    out
}

fn substrate_byte(substrate: Substrate) -> u8 {
    match substrate {
        Substrate::Soup => 0,
        Substrate::Life => 1,
    }
}

fn lineage_bytes(lineages: &[u64]) -> Vec<u8> {
    let mut out = Vec::with_capacity(lineages.len() * LINEAGE_BYTES);
    for id in lineages {
        out.extend_from_slice(&id.to_le_bytes());
    }
    out
}

fn word_bytes(words: &[u32]) -> Vec<u8> {
    let mut out = Vec::with_capacity(words.len() * WORD_BYTES);
    for word in words {
        out.extend_from_slice(&word.to_le_bytes());
    }
    out
}

fn words_from(bytes: &[u8]) -> Vec<u32> {
    let (words, _) = bytes.as_chunks::<WORD_BYTES>();
    words.iter().copied().map(u32::from_le_bytes).collect()
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
        VERSION_RAGGED => HEADER_LEN_V4,
        VERSION_STOCKED => HEADER_LEN_V5,
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
        tape_cap: if header_len >= HEADER_LEN_V4 {
            word(HEADER_LEN + 8)
        } else {
            word(14)
        },
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
    // The lengths alone cannot tell the cap they were written under: every one of them
    // fitting a narrower slot is no evidence the world had no more room than that.
    if header_len >= HEADER_LEN_V4 && header.tape_cap != params.tape_cap() {
        return Err(SnapshotError::Mismatch {
            field: "max_tape_len",
        });
    }

    let payload_at = |at: usize| {
        usize::try_from(u64::from_le_bytes(
            bytes[at..at + 8].try_into().expect("eight bytes"),
        ))
        .map_err(|_| SnapshotError::Truncated)
    };
    let body = &bytes[header_len..];
    let (cell_payload, lineage_payload, len_payload, stock_payload) = match header_len {
        HEADER_LEN_V5 => {
            let cells_len = payload_at(HEADER_LEN_V2)?;
            let tags_len = payload_at(HEADER_LEN)?;
            let lens_len = payload_at(HEADER_LEN_V4)?;
            let payloads = cells_len
                .checked_add(tags_len)
                .and_then(|so_far| so_far.checked_add(lens_len))
                .ok_or(SnapshotError::Truncated)?;
            if body.len() < payloads {
                return Err(SnapshotError::Truncated);
            }
            (
                &body[..cells_len],
                Some(&body[cells_len..cells_len + tags_len]),
                (lens_len > 0).then(|| &body[cells_len + tags_len..payloads]),
                Some(&body[payloads..]),
            )
        }
        HEADER_LEN_V4 => {
            let cells_len = payload_at(HEADER_LEN_V2)?;
            let tags_len = payload_at(HEADER_LEN)?;
            let payloads = cells_len
                .checked_add(tags_len)
                .ok_or(SnapshotError::Truncated)?;
            if body.len() < payloads {
                return Err(SnapshotError::Truncated);
            }
            (
                &body[..cells_len],
                Some(&body[cells_len..cells_len + tags_len]),
                Some(&body[cells_len + tags_len..]),
                None,
            )
        }
        HEADER_LEN => {
            let cells_len = payload_at(HEADER_LEN_V2)?;
            if body.len() < cells_len {
                return Err(SnapshotError::Truncated);
            }
            (&body[..cells_len], Some(&body[cells_len..]), None, None)
        }
        _ => (body, None, None, None),
    };

    let lens = len_payload
        .map(|payload| decode_lens(params, payload))
        .transpose()?;
    let expected = match &lens {
        Some(lens) => lens.iter().map(|len| *len as usize).sum(),
        None => params.cell_count() * params.stride(),
    };
    let live = inflate_bounded(cell_payload, expected)?;
    if live.len() != expected {
        return Err(SnapshotError::Mismatch {
            field: "cell count",
        });
    }
    let cells = match &lens {
        Some(lens) => into_slots(&live, lens, params.stride()),
        None => live,
    };

    let lineages = lineage_payload
        .map(|payload| decode_lineages(params, payload))
        .transpose()?;
    let stock = stock_payload
        .map(|payload| decode_stock(params, payload))
        .transpose()?;
    Ok(Restored {
        header,
        cells,
        lineages,
        lens,
        stock,
    })
}

/// The ragged live bytes laid back into the flat array of `stride`-wide slots the world
/// holds them in, every byte past a tape's length left zero as the world leaves it.
fn into_slots(live: &[u8], lens: &[u32], stride: usize) -> Vec<u8> {
    let mut cells = vec![0u8; lens.len() * stride];
    let mut at = 0usize;
    for (cell, len) in lens.iter().enumerate() {
        let len = *len as usize;
        cells[cell * stride..cell * stride + len].copy_from_slice(&live[at..at + len]);
        at += len;
    }
    cells
}

/// The live tape lengths, refused unless there is one per cell and each fits a slot: a
/// blob written under a wider cap cannot be restored into a narrower world.
fn decode_lens(params: &Params, payload: &[u8]) -> Result<Vec<u32>, SnapshotError> {
    let expected = params.cell_count() * WORD_BYTES;
    let bytes = inflate_bounded(payload, expected)?;
    if bytes.len() != expected {
        return Err(SnapshotError::Mismatch {
            field: "cell count",
        });
    }
    let lens = words_from(&bytes);
    if lens
        .iter()
        .any(|len| *len == 0 || *len as usize > params.stride())
    {
        return Err(SnapshotError::Mismatch { field: "tape_len" });
    }
    Ok(lens)
}

/// The energy stocks, refused unless there is one per cell and none holds more than the
/// world's cap: a blob written under a richer economy cannot be restored into a poorer one.
fn decode_stock(params: &Params, payload: &[u8]) -> Result<Vec<u32>, SnapshotError> {
    let expected = params.cell_count() * WORD_BYTES;
    let bytes = inflate_bounded(payload, expected)?;
    if bytes.len() != expected {
        return Err(SnapshotError::Mismatch {
            field: "cell count",
        });
    }
    let stock = words_from(&bytes);
    if stock.iter().any(|held| *held > params.energy_stock_cap) {
        return Err(SnapshotError::Mismatch {
            field: "energy_stock_cap",
        });
    }
    Ok(stock)
}

fn decode_lineages(params: &Params, payload: &[u8]) -> Result<Vec<u64>, SnapshotError> {
    let expected = params.lineage_count() * LINEAGE_BYTES;
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
/// The `legacy-fixtures` feature hands them to the crates downstream that do too.
#[cfg(any(test, feature = "legacy-fixtures"))]
pub mod legacy {
    use super::*;

    /// A snapshot as the first released engine wrote it: the 26-byte header, version 1.
    pub fn v1_blob(params: &Params, epoch: u64, cells: &[u8]) -> Vec<u8> {
        let mut out = prefix(params, 1, epoch);
        out.extend_from_slice(&metrics::compress(cells));
        out
    }

    /// A snapshot as the engine wrote it before lineage tags: the 54-byte header, version
    /// 2, the transition tracker and the cell payload, and nothing after it.
    pub fn v2_blob(
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
        out.push(substrate_byte(params.substrate));
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
            tape_cap: params.tape_cap(),
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
        let bytes = encode(&header(&params, 99), &cells, &lineages(&params), &[], &[]);
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

        let bytes = encode(&header(&params, 3), &cells, &tags, &[], &[]);

        assert_eq!(decode(&params, &bytes).unwrap().lineages, Some(tags));
    }

    /// The life substrate carries no ancestry, so a version 3 blob of a life world holds
    /// an empty tag payload — which has to inflate back to no lineages rather than fail
    /// the count the params describe.
    #[test]
    fn a_life_world_round_trips_with_an_empty_lineage_payload() {
        let params = Params {
            substrate: Substrate::Life,
            ..params()
        };
        let cells: Vec<u8> = (0..params.cell_count()).map(|i| (i % 2) as u8).collect();

        let bytes = encode(&header(&params, 5), &cells, &[], &[], &[]);

        let restored = decode(&params, &bytes).unwrap();
        assert_eq!(restored.cells, cells);
        assert_eq!(restored.header.epoch, 5);
        assert_eq!(restored.lineages, Some(Vec::new()));
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
            &[],
            &[],
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
            &[],
            &[],
        );

        assert!(matches!(
            decode(&params, &bytes),
            Err(SnapshotError::Mismatch {
                field: "cell count"
            })
        ));
    }

    /// Version 4: the ragged live bytes go in and come back laid into the `stride`-wide
    /// slots the world holds them in, the lengths beside them and the padding zero.
    #[test]
    fn round_trips_the_live_bytes_and_the_lengths_of_a_ragged_world() {
        let params = Params {
            max_tape_len: 32,
            ..params()
        };
        let lens: Vec<u32> = (0..params.cell_count() as u32)
            .map(|cell| 8 + cell % 3)
            .collect();
        let live: Vec<u8> = (0..lens.iter().sum::<u32>()).map(|at| at as u8).collect();

        let bytes = encode(&header(&params, 7), &live, &lineages(&params), &lens, &[]);

        assert_eq!(bytes[4], VERSION_RAGGED);
        let restored = decode(&params, &bytes).unwrap();
        assert_eq!(restored.lens, Some(lens.clone()));
        let mut at = 0;
        for (cell, len) in lens.iter().enumerate() {
            let len = *len as usize;
            let slot = &restored.cells[cell * params.stride()..(cell + 1) * params.stride()];
            assert_eq!(&slot[..len], &live[at..at + len], "cell {cell}");
            assert!(slot[len..].iter().all(|byte| *byte == 0), "cell {cell}");
            at += len;
        }
    }

    /// A round trip through this file's own encoder cannot see a field that moved, and
    /// Postgres holds blobs a later build has to read. So the version 4 layout is pinned
    /// here field by field, offset by offset, payloads in the order they follow the
    /// header: cells, tags, lengths.
    #[test]
    fn pins_the_version_four_layout() {
        let params = Params {
            max_tape_len: 300,
            ..params()
        };
        let lens: Vec<u32> = (0..params.cell_count() as u32)
            .map(|cell| 4 + cell)
            .collect();
        let live: Vec<u8> = (0..lens.iter().sum::<u32>()).map(|at| at as u8).collect();
        let tags = lineages(&params);

        let bytes = encode(&header(&params, 9), &live, &tags, &lens, &[]);

        assert_eq!(bytes[..4], MAGIC);
        assert_eq!(bytes[4], VERSION_RAGGED);
        assert_eq!(bytes[5], substrate_byte(params.substrate));
        assert_eq!(bytes[6..10], params.width.to_le_bytes());
        assert_eq!(bytes[10..14], params.height.to_le_bytes());
        assert_eq!(bytes[14..18], params.tape_len.to_le_bytes());
        assert_eq!(bytes[18..26], 9u64.to_le_bytes());
        assert_eq!(bytes[26..34], NO_EPOCH.to_le_bytes(), "no candidate");
        assert_eq!(bytes[34..38], 0u32.to_le_bytes(), "nothing held");
        assert_eq!(bytes[38..46], NO_EPOCH.to_le_bytes(), "nothing settled");
        assert_eq!(bytes[46..54], NO_EPOCH.to_le_bytes(), "no last epoch");
        assert_eq!(bytes[70..74], 300u32.to_le_bytes(), "the cap");

        let cells_len = u64::from_le_bytes(bytes[54..62].try_into().unwrap()) as usize;
        let tags_len = u64::from_le_bytes(bytes[62..70].try_into().unwrap()) as usize;
        let body = &bytes[HEADER_LEN_V4..];
        assert_eq!(
            inflate_bounded(&body[..cells_len], live.len()).unwrap(),
            live
        );
        assert_eq!(
            inflate_bounded(
                &body[cells_len..cells_len + tags_len],
                tags.len() * LINEAGE_BYTES
            )
            .unwrap(),
            lineage_bytes(&tags)
        );
        assert_eq!(
            inflate_bounded(&body[cells_len + tags_len..], lens.len() * WORD_BYTES).unwrap(),
            word_bytes(&lens)
        );
    }

    /// Version 5: the stocks travel with the tapes, so a stocked run resumed from a
    /// snapshot carries the energy its cells had rather than a fresh full world. A stocked
    /// world of fixed-length tapes writes no lengths at all, and reads back as one.
    #[test]
    fn round_trips_the_energy_stocks_of_a_stocked_world() {
        let params = Params {
            energy_influx: 4,
            energy_stock_cap: 64,
            ..params()
        };
        let cells = vec![3u8; params.cell_count() * params.stride()];
        let stock: Vec<u32> = (0..params.cell_count() as u32)
            .map(|cell| cell % 65)
            .collect();

        let bytes = encode(
            &header(&params, 12),
            &cells,
            &lineages(&params),
            &[],
            &stock,
        );

        assert_eq!(bytes[4], VERSION_STOCKED);
        let restored = decode(&params, &bytes).unwrap();
        assert_eq!(restored.cells, cells);
        assert_eq!(restored.header.epoch, 12);
        assert_eq!(restored.lens, None, "a fixed-length world wrote lengths");
        assert_eq!(restored.stock, Some(stock));
    }

    /// A world may hold both: the lengths and the stocks follow the tapes and the tags, in
    /// that order, and each comes back its own.
    #[test]
    fn round_trips_the_lengths_and_the_stocks_of_a_growing_stocked_world() {
        let params = Params {
            max_tape_len: 32,
            energy_influx: 4,
            energy_stock_cap: 64,
            ..params()
        };
        let lens: Vec<u32> = (0..params.cell_count() as u32)
            .map(|cell| 8 + cell % 3)
            .collect();
        let live: Vec<u8> = (0..lens.iter().sum::<u32>()).map(|at| at as u8).collect();
        let stock = vec![17u32; params.cell_count()];

        let bytes = encode(
            &header(&params, 6),
            &live,
            &lineages(&params),
            &lens,
            &stock,
        );

        assert_eq!(bytes[4], VERSION_STOCKED);
        let restored = decode(&params, &bytes).unwrap();
        assert_eq!(restored.lens, Some(lens));
        assert_eq!(restored.stock, Some(stock));
    }

    /// A stock over the world's cap is not this world's: restoring it would hand cells
    /// energy the params say they cannot hold.
    #[test]
    fn rejects_a_stock_written_under_a_richer_economy() {
        let params = Params {
            energy_influx: 4,
            energy_stock_cap: 64,
            ..params()
        };
        let cells = vec![0u8; params.cell_count() * params.stride()];
        let bytes = encode(
            &header(&params, 1),
            &cells,
            &lineages(&params),
            &[],
            &vec![4096u32; params.cell_count()],
        );

        assert!(matches!(
            decode(&params, &bytes),
            Err(SnapshotError::Mismatch {
                field: "energy_stock_cap"
            })
        ));
    }

    /// The lengths alone cannot tell the cap they were written under: a blob whose tapes
    /// all happen to fit a narrower world would restore into it silently, and the run
    /// would carry room it was never given. The version 4 header carries the cap for
    /// exactly that case.
    #[test]
    fn rejects_a_ragged_blob_written_under_another_cap() {
        let params = Params {
            max_tape_len: 512,
            ..params()
        };
        let lens = vec![8u32; params.cell_count()];
        let live = vec![b'a'; lens.len() * 8];
        let bytes = encode(&header(&params, 4), &live, &lineages(&params), &lens, &[]);

        let narrower = Params {
            max_tape_len: 128,
            ..params.clone()
        };
        assert!(matches!(
            decode(&narrower, &bytes),
            Err(SnapshotError::Mismatch {
                field: "max_tape_len"
            })
        ));
        assert!(decode(&params, &bytes).is_ok());
    }

    /// A length no slot of this world can hold — a blob written under a wider cap — is
    /// refused, rather than laid into a slot it overruns; and so is a length of zero,
    /// which no tape ever has.
    #[test]
    fn rejects_lengths_that_do_not_fit_the_params() {
        let params = params();
        let over_the_cap = encode(
            &header(&params, 0),
            &vec![0u8; 16 * params.cell_count()],
            &lineages(&params),
            &vec![16u32; params.cell_count()],
            &[],
        );
        assert!(matches!(
            decode(&params, &over_the_cap),
            Err(SnapshotError::Mismatch { field: "tape_len" })
        ));

        let empty_tapes = encode(
            &header(&params, 0),
            &[],
            &lineages(&params),
            &vec![0u32; params.cell_count()],
            &[],
        );
        assert!(matches!(
            decode(&params, &empty_tapes),
            Err(SnapshotError::Mismatch { field: "tape_len" })
        ));
    }

    /// A stock payload that does not count the cells is refused rather than laid into a
    /// world it cannot fill: `World::from_snapshot` leans on this length holding.
    #[test]
    fn rejects_a_stock_that_does_not_count_the_cells() {
        let params = Params {
            energy_influx: 4,
            energy_stock_cap: 64,
            ..params()
        };
        let cells = vec![0u8; params.cell_count() * params.stride()];
        let bytes = encode(
            &header(&params, 1),
            &cells,
            &lineages(&params),
            &[],
            &vec![8u32; params.cell_count() - 1],
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
        let bytes = encode(&header(&params, 0), &cells, &vec![0u64; 128], &[], &[]);

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
        let mut bytes = encode(
            &header(&params, 0),
            &[0u8; 128],
            &lineages(&params),
            &[],
            &[],
        );
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
        let bytes = encode(&header(&params, 0), &cells, &lineages(&params), &[], &[]);

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
        future[4] = VERSION_STOCKED + 1;
        assert!(matches!(
            decode(&params, &future),
            Err(SnapshotError::UnsupportedVersion(6))
        ));
    }
}
