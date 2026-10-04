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
//!
//! Versions 6, 7 and 8 are versions 3, 4 and 5 carrying the relative transition reading's
//! state as well (`docs/design_record.md`, 2026-09-19): the same header with that block's
//! length last, and the block itself after every payload. Stripping the block off the end
//! leaves the container the older version wrote, which is how a blob of either shape is
//! read by the one set of payload offsets.
//!
//! Versions 9, 10 and 11 are versions 6, 7 and 8 carrying a metabolism tape per cell as
//! well (DESIGN §1.1, "The metabolism tape"): after the relative block's length the header
//! holds the metabolism payload's length and the tape's length per cell, and that payload
//! sits between the last of the older payloads and the relative block. Stripping it and
//! those two fields leaves the container the older version wrote. A world without the tape
//! writes 6, 7 or 8 as before, and a blob of those versions reads as a world without it.
//!
//! Versions 12, 13 and 14 are versions 9, 10 and 11 for metabolism tapes that can grow
//! (`docs/design_record.md`, 2026-10-04, Genes slice A): the tape-length field names the
//! cap, a third metabolism field holds the length of a payload of one live length per
//! cell, the metabolism payload holds the live bytes end to end, and the lengths follow
//! it, before the relative block. A world whose tapes cannot grow writes 9, 10 or 11 as
//! before.

use crate::metrics::{self, PendingSample, RelativeState, TransitionState};
use crate::params::{ParamError, Params, Substrate, META_LEN_MAX};
use flate2::read::ZlibDecoder;
use std::fmt;
use std::io::Read;

pub const MAGIC: [u8; 4] = *b"LSNP";
pub const VERSION: u8 = 3;
/// The version a world whose tapes can grow writes; it carries the lengths.
pub const VERSION_RAGGED: u8 = 4;
/// The version a world whose cells hold energy writes; it carries the stocks.
pub const VERSION_STOCKED: u8 = 5;
/// The versions that carry the relative transition reading beside the constant one — one
/// per payload shape above, since the block is an addition to each rather than a shape of
/// its own. Every world written since writes one of them.
pub const VERSION_RELATIVE: u8 = 6;
pub const VERSION_RELATIVE_RAGGED: u8 = 7;
pub const VERSION_RELATIVE_STOCKED: u8 = 8;
/// The versions that carry the metabolism tapes beside the relative reading, one per
/// payload shape again.
pub const VERSION_META: u8 = 9;
pub const VERSION_META_RAGGED: u8 = 10;
pub const VERSION_META_STOCKED: u8 = 11;
/// The versions that carry metabolism tapes that can grow, with their live lengths.
pub const VERSION_META_GROWN: u8 = 12;
pub const VERSION_META_GROWN_RAGGED: u8 = 13;
pub const VERSION_META_GROWN_STOCKED: u8 = 14;
pub const HEADER_LEN: usize = 62;
const HEADER_LEN_V4: usize = 74;
const HEADER_LEN_V5: usize = 82;
/// Version 2 carried tapes only, version 1 not even the transition tracker; Postgres
/// still holds both, and every run they belong to must stay resumable.
const HEADER_LEN_V2: usize = 54;
const HEADER_LEN_V1: usize = 26;
const LINEAGE_BYTES: usize = 8;
/// The relative block's fixed part: the hold machine, the baseline as a sum and a count,
/// and how many pending samples follow it.
const RELATIVE_LEN: usize = 36;
/// One pending sample: its epoch, its `compress_ratio` and whether its alphabet held.
const PENDING_LEN: usize = 17;
/// The `u64` holding the relative block's length, written last in the header.
const RELATIVE_FIELD_BYTES: usize = 8;
/// The header of a version 6 container: the version 3 header and that length.
pub const HEADER_LEN_RELATIVE: usize = HEADER_LEN + RELATIVE_FIELD_BYTES;
/// The metabolism fields after the relative block's length: the payload's length as a
/// `u64` and the tape's length per cell as a `u32`.
const META_FIELD_BYTES: usize = 12;
/// The `u64` a grown metabolism section adds to them: its live-length payload's length.
const META_LENS_FIELD_BYTES: usize = 8;
const WORD_BYTES: usize = 4;
const NO_EPOCH: i64 = -1;

#[derive(Debug)]
pub enum SnapshotError {
    Truncated,
    BadMagic,
    UnsupportedVersion(u8),
    Mismatch {
        field: &'static str,
    },
    Corrupt(std::io::Error),
    /// A world at or before `metrics::TRANSITION_BASELINE_EPOCHS`, which a descendant
    /// cannot start from: its own baseline would be read on its parent's world.
    InsideBaselineWindow {
        epoch: u64,
    },
    /// A descendant's params that validation refuses. A new run is refused them at
    /// `World::new`; a descendant is refused them here, at `World::descend`.
    InvalidParams(ParamError),
}

impl fmt::Display for SnapshotError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Truncated => write!(f, "snapshot is shorter than its header"),
            Self::BadMagic => write!(f, "not a snapshot"),
            Self::UnsupportedVersion(v) => write!(f, "unsupported snapshot version {v}"),
            Self::Mismatch { field } => write!(f, "snapshot {field} does not match the params"),
            Self::Corrupt(e) => write!(f, "snapshot payload is corrupt: {e}"),
            Self::InsideBaselineWindow { epoch } => write!(
                f,
                "a world at epoch {epoch} is inside the transition baseline window and \
                 cannot be descended from"
            ),
            Self::InvalidParams(e) => write!(f, "a descendant's params are refused: {e}"),
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
/// every format written before cells held energy, and `meta` for every format written
/// without a metabolism tape.
pub struct Restored {
    pub header: Header,
    pub cells: Vec<u8>,
    pub lineages: Option<Vec<u64>>,
    pub lens: Option<Vec<u32>>,
    pub stock: Option<Vec<u32>>,
    pub meta: Option<Metabolism>,
}

/// The metabolism tapes a blob carries: `len` bytes per cell, cell by cell — on a channel
/// that grows, slots `len` (the cap) bytes wide holding each cell's live bytes, zero past
/// them, and those live lengths in `lens`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Metabolism {
    pub len: u32,
    pub tapes: Vec<u8>,
    pub lens: Option<Vec<u32>>,
}

/// The metabolism tapes a world writes: `slot` bytes per cell, cell by cell, and where they
/// can grow, each cell's live length in `lens`. Empty `slots` for a world without them.
#[derive(Debug, Clone, Copy, Default)]
pub struct MetaTapes<'a> {
    pub slots: &'a [u8],
    pub slot: usize,
    pub lens: &'a [u32],
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
    encode_compressed_with_meta(header, payload, lineages, lens, stock, MetaTapes::default())
}

/// `encode_compressed` for a world that may carry metabolism tapes: `meta` holds one tape
/// per cell of the header's world, and is empty for a world without them, which is then
/// written exactly as `encode_compressed` writes it.
pub fn encode_compressed_with_meta(
    header: &Header,
    payload: &[u8],
    lineages: &[u64],
    lens: &[u32],
    stock: &[u32],
    meta: MetaTapes<'_>,
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
    let metabolic = !meta.slots.is_empty();
    let grown = metabolic && !meta.lens.is_empty();
    out.push(match (stocked, ragged, metabolic, grown) {
        (true, _, false, _) => VERSION_RELATIVE_STOCKED,
        (false, true, false, _) => VERSION_RELATIVE_RAGGED,
        (false, false, false, _) => VERSION_RELATIVE,
        (true, _, true, false) => VERSION_META_STOCKED,
        (false, true, true, false) => VERSION_META_RAGGED,
        (false, false, true, false) => VERSION_META,
        (true, _, true, true) => VERSION_META_GROWN_STOCKED,
        (false, true, true, true) => VERSION_META_GROWN_RAGGED,
        (false, false, true, true) => VERSION_META_GROWN,
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
    let relative = relative_bytes(&header.transition.relative);
    out.extend_from_slice(&(relative.len() as u64).to_le_bytes());
    let (tapes, meta_lens) = match (metabolic, grown) {
        (false, _) => (Vec::new(), Vec::new()),
        (true, false) => (metrics::compress(meta.slots), Vec::new()),
        (true, true) => (
            metrics::compress(&metrics::Tapes::ragged(meta.slots, meta.slot, meta.lens).bytes()),
            metrics::compress(&word_bytes(meta.lens)),
        ),
    };
    if metabolic {
        out.extend_from_slice(&(tapes.len() as u64).to_le_bytes());
        out.extend_from_slice(&(meta.slot as u32).to_le_bytes());
    }
    if grown {
        out.extend_from_slice(&(meta_lens.len() as u64).to_le_bytes());
    }
    out.extend_from_slice(payload);
    out.extend_from_slice(&tags);
    if ragged {
        out.extend_from_slice(&lengths);
    }
    if stocked {
        out.extend_from_slice(&metrics::compress(&word_bytes(stock)));
    }
    out.extend_from_slice(&tapes);
    out.extend_from_slice(&meta_lens);
    out.extend_from_slice(&relative);
    out
}

/// The relative reading's state, written after every payload so that stripping it leaves
/// the container the version before it wrote, byte for byte.
fn relative_bytes(state: &RelativeState) -> Vec<u8> {
    let mut out = Vec::with_capacity(RELATIVE_LEN + state.pending.len() * PENDING_LEN);
    out.extend_from_slice(&epoch_field(state.candidate).to_le_bytes());
    out.extend_from_slice(&state.held.to_le_bytes());
    out.extend_from_slice(&epoch_field(state.settled).to_le_bytes());
    out.extend_from_slice(&state.baseline_sum.to_le_bytes());
    out.extend_from_slice(&state.baseline_count.to_le_bytes());
    out.extend_from_slice(&(state.pending.len() as u32).to_le_bytes());
    for sample in &state.pending {
        out.extend_from_slice(&sample.epoch.to_le_bytes());
        out.extend_from_slice(&sample.ratio.to_le_bytes());
        out.push(u8::from(sample.uncollapsed));
    }
    out
}

fn relative_from(bytes: &[u8]) -> Result<RelativeState, SnapshotError> {
    if bytes.len() < RELATIVE_LEN {
        return Err(SnapshotError::Truncated);
    }
    let signed = |at: usize| i64::from_le_bytes(bytes[at..at + 8].try_into().expect("eight bytes"));
    let word = |at: usize| u32::from_le_bytes(bytes[at..at + 4].try_into().expect("four bytes"));
    let float = |at: usize| f64::from_le_bytes(bytes[at..at + 8].try_into().expect("eight bytes"));
    let count = word(32) as usize;
    if bytes.len() < RELATIVE_LEN + count * PENDING_LEN {
        return Err(SnapshotError::Truncated);
    }
    let pending = (0..count)
        .map(|index| {
            let at = RELATIVE_LEN + index * PENDING_LEN;
            PendingSample {
                epoch: u64::from_le_bytes(bytes[at..at + 8].try_into().expect("eight bytes")),
                ratio: float(at + 8),
                uncollapsed: bytes[at + 16] != 0,
            }
        })
        .collect();
    Ok(RelativeState {
        baseline_sum: float(20),
        baseline_count: word(28),
        pending,
        candidate: epoch_from_field(signed(0)),
        held: word(8),
        settled: epoch_from_field(signed(12)),
    })
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
    decode_within(params, bytes, params.energy_stock_cap)
}

/// The same reading for a descendant's start, whose economy may differ from its parent's:
/// the stocks are not held to the child's cap, since the child clamps them to it rather
/// than being refused (`World::descend`).
pub fn decode_for_descent(params: &Params, bytes: &[u8]) -> Result<Restored, SnapshotError> {
    decode_within(params, bytes, u32::MAX)
}

fn decode_within(params: &Params, bytes: &[u8], stock_cap: u32) -> Result<Restored, SnapshotError> {
    if bytes.len() < HEADER_LEN_V1 {
        return Err(SnapshotError::Truncated);
    }
    if bytes[..4] != MAGIC {
        return Err(SnapshotError::BadMagic);
    }
    // The payload shape the blob was written in, and whether the relative block follows
    // it: the shapes read alike, since the block sits past every payload.
    let (shape, carries_relative, carries_meta, meta_grown) = match bytes[4] {
        1 => (HEADER_LEN_V1, false, false, false),
        2 => (HEADER_LEN_V2, false, false, false),
        VERSION => (HEADER_LEN, false, false, false),
        VERSION_RAGGED => (HEADER_LEN_V4, false, false, false),
        VERSION_STOCKED => (HEADER_LEN_V5, false, false, false),
        VERSION_RELATIVE => (HEADER_LEN, true, false, false),
        VERSION_RELATIVE_RAGGED => (HEADER_LEN_V4, true, false, false),
        VERSION_RELATIVE_STOCKED => (HEADER_LEN_V5, true, false, false),
        VERSION_META => (HEADER_LEN, true, true, false),
        VERSION_META_RAGGED => (HEADER_LEN_V4, true, true, false),
        VERSION_META_STOCKED => (HEADER_LEN_V5, true, true, false),
        VERSION_META_GROWN => (HEADER_LEN, true, true, true),
        VERSION_META_GROWN_RAGGED => (HEADER_LEN_V4, true, true, true),
        VERSION_META_GROWN_STOCKED => (HEADER_LEN_V5, true, true, true),
        version => return Err(SnapshotError::UnsupportedVersion(version)),
    };
    let header_len = shape
        + if carries_relative {
            RELATIVE_FIELD_BYTES
        } else {
            0
        }
        + if carries_meta { META_FIELD_BYTES } else { 0 }
        + if meta_grown { META_LENS_FIELD_BYTES } else { 0 };
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
    let relative_len = match carries_relative {
        true => usize::try_from(u64::from_le_bytes(
            bytes[shape..shape + 8].try_into().expect("eight bytes"),
        ))
        .map_err(|_| SnapshotError::Truncated)?,
        false => 0,
    };
    let (meta_payload_len, meta_len) = match carries_meta {
        true => (
            usize::try_from(u64::from_le_bytes(
                bytes[shape + RELATIVE_FIELD_BYTES..shape + RELATIVE_FIELD_BYTES + 8]
                    .try_into()
                    .expect("eight bytes"),
            ))
            .map_err(|_| SnapshotError::Truncated)?,
            word(shape + RELATIVE_FIELD_BYTES + 8),
        ),
        false => (0, 0),
    };
    let meta_lens_len = match meta_grown {
        true => {
            let at = shape + RELATIVE_FIELD_BYTES + META_FIELD_BYTES;
            usize::try_from(u64::from_le_bytes(
                bytes[at..at + 8].try_into().expect("eight bytes"),
            ))
            .map_err(|_| SnapshotError::Truncated)?
        }
        false => 0,
    };
    let trailer_len = relative_len
        .checked_add(meta_payload_len)
        .and_then(|so_far| so_far.checked_add(meta_lens_len))
        .ok_or(SnapshotError::Truncated)?;
    if bytes.len() - header_len < trailer_len {
        return Err(SnapshotError::Truncated);
    }
    let payloads_end = bytes.len() - trailer_len;
    let relative_at = bytes.len() - relative_len;
    let transition = if shape > HEADER_LEN_V1 {
        TransitionState {
            candidate: epoch_from_field(signed(26)),
            held: word(34),
            settled: epoch_from_field(signed(38)),
            last_epoch: epoch_from_field(signed(46)),
            relative: match carries_relative {
                true => relative_from(&bytes[relative_at..])?,
                false => RelativeState::default(),
            },
        }
    } else {
        TransitionState::default()
    };
    let header = Header {
        substrate,
        width: word(6),
        height: word(10),
        tape_len: word(14),
        tape_cap: if shape >= HEADER_LEN_V4 {
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
    if shape >= HEADER_LEN_V4 && header.tape_cap != params.tape_cap() {
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
    let body = &bytes[header_len..payloads_end];
    let (cell_payload, lineage_payload, len_payload, stock_payload) = match shape {
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
        .map(|payload| decode_stock(params, payload, stock_cap))
        .transpose()?;
    let meta_lens_at = payloads_end + meta_payload_len;
    let meta = carries_meta
        .then(|| {
            decode_meta(
                params,
                &bytes[payloads_end..meta_lens_at],
                meta_len,
                meta_grown.then(|| &bytes[meta_lens_at..relative_at]),
            )
        })
        .transpose()?;
    Ok(Restored {
        header,
        cells,
        lineages,
        lens,
        stock,
        meta,
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

/// The energy stocks, refused unless there is one per cell and none holds more than `cap`
/// — on a restore the world's own cap: a blob written under a richer economy cannot be
/// restored into a poorer one.
fn decode_stock(params: &Params, payload: &[u8], cap: u32) -> Result<Vec<u32>, SnapshotError> {
    let expected = params.cell_count() * WORD_BYTES;
    let bytes = inflate_bounded(payload, expected)?;
    if bytes.len() != expected {
        return Err(SnapshotError::Mismatch {
            field: "cell count",
        });
    }
    let stock = words_from(&bytes);
    if stock.iter().any(|held| *held > cap) {
        return Err(SnapshotError::Mismatch {
            field: "energy_stock_cap",
        });
    }
    Ok(stock)
}

/// The metabolism tapes, refused unless the blob names a length and holds exactly one tape
/// of it per cell — or where they grow, one live length per cell, each from 1 to that
/// length, and exactly those live bytes. Whether the length is the params' own is the
/// world's to judge: a resume holds it to them and a descendant need not
/// (`World::descend`).
fn decode_meta(
    params: &Params,
    payload: &[u8],
    len: u32,
    lens_payload: Option<&[u8]>,
) -> Result<Metabolism, SnapshotError> {
    if len == 0 || len > META_LEN_MAX {
        return Err(SnapshotError::Mismatch { field: "meta_len" });
    }
    let lens = lens_payload
        .map(|payload| {
            let expected = params.cell_count() * WORD_BYTES;
            let bytes = inflate_bounded(payload, expected)?;
            if bytes.len() != expected {
                return Err(SnapshotError::Mismatch {
                    field: "cell count",
                });
            }
            let lens = words_from(&bytes);
            match lens.iter().all(|live| (1..=len).contains(live)) {
                true => Ok(lens),
                false => Err(SnapshotError::Mismatch { field: "meta_len" }),
            }
        })
        .transpose()?;
    let expected = match &lens {
        Some(lens) => lens.iter().map(|live| *live as usize).sum(),
        None => params
            .cell_count()
            .checked_mul(len as usize)
            .ok_or(SnapshotError::Truncated)?,
    };
    let live = inflate_bounded(payload, expected)?;
    if live.len() != expected {
        return Err(SnapshotError::Mismatch {
            field: "cell count",
        });
    }
    let tapes = match &lens {
        Some(lens) => into_slots(&live, lens, len as usize),
        None => live,
    };
    Ok(Metabolism { len, tapes, lens })
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
        transition: &TransitionState,
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
        assert!(bytes.len() < cells.len() + HEADER_LEN_RELATIVE + RELATIVE_LEN + 64);

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
            relative: RelativeState {
                baseline_sum: 4.5,
                baseline_count: 5,
                pending: vec![PendingSample {
                    epoch: 300,
                    ratio: 0.81,
                    uncollapsed: true,
                }],
                candidate: Some(420),
                held: 1,
                settled: None,
            },
        };
        let bytes = encode(
            &Header {
                transition: transition.clone(),
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
            relative: RelativeState::default(),
        };

        let restored = decode(&params, &v2_blob(&params, 20, &transition, &cells)).unwrap();
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

        assert_eq!(bytes[4], VERSION_RELATIVE_RAGGED);
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
        assert_eq!(bytes[4], VERSION_RELATIVE_RAGGED);
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
        let relative_len = u64::from_le_bytes(bytes[74..82].try_into().unwrap()) as usize;
        assert_eq!(relative_len, RELATIVE_LEN, "a tracker with nothing pending");
        let body = &bytes[HEADER_LEN_V4 + RELATIVE_FIELD_BYTES..bytes.len() - relative_len];
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

        assert_eq!(bytes[4], VERSION_RELATIVE_STOCKED);
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

        assert_eq!(bytes[4], VERSION_RELATIVE_STOCKED);
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
    /// world it cannot fill: one reading per cell is what a world's stock is.
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
        future[4] = VERSION_META_GROWN_STOCKED + 1;
        assert!(matches!(
            decode(&params, &future),
            Err(SnapshotError::UnsupportedVersion(15))
        ));
    }

    fn tapes(params: &Params, len: usize) -> Vec<u8> {
        (0..params.cell_count() * len)
            .map(|at| (at * 7) as u8)
            .collect()
    }

    /// Metabolism tapes of one length, `len` bytes a cell.
    fn one_length(slots: &[u8], len: usize) -> MetaTapes<'_> {
        MetaTapes {
            slots,
            slot: len,
            lens: &[],
        }
    }

    /// Versions 12 to 14: grown metabolism tapes travel beside every payload shape as their
    /// live bytes and lengths, and come back laid into slots as wide as the cap, zero past
    /// each tape, as the world holds them.
    #[test]
    fn round_trips_grown_metabolism_tapes_in_every_payload_shape() {
        let fixed_cells = params();
        let stocked = Params {
            energy_influx: 4,
            energy_stock_cap: 64,
            ..params()
        };
        let ragged = Params {
            max_tape_len: 32,
            ..params()
        };
        let lens = vec![9u32; ragged.cell_count()];
        let stock = vec![5u32; stocked.cell_count()];
        let cap = 40usize;
        for (params, lens, stock, version) in [
            (&fixed_cells, &[][..], &[][..], VERSION_META_GROWN),
            (&ragged, &lens[..], &[][..], VERSION_META_GROWN_RAGGED),
            (&stocked, &[][..], &stock[..], VERSION_META_GROWN_STOCKED),
        ] {
            let live = match lens.is_empty() {
                true => params.cell_count() * params.stride(),
                false => lens.iter().sum::<u32>() as usize,
            };
            let cells: Vec<u8> = (0..live).map(|at| at as u8).collect();
            let meta_lens: Vec<u32> = (0..params.cell_count())
                .map(|cell| 1 + (cell % cap) as u32)
                .collect();
            let mut slots = vec![0u8; params.cell_count() * cap];
            for (cell, live) in meta_lens.iter().enumerate() {
                for at in 0..*live as usize {
                    slots[cell * cap + at] = (cell + at) as u8 | 1;
                }
            }
            let bytes = encode_compressed_with_meta(
                &header(params, 40),
                &metrics::compress(&cells),
                &lineages(params),
                lens,
                stock,
                MetaTapes {
                    slots: &slots,
                    slot: cap,
                    lens: &meta_lens,
                },
            );

            assert_eq!(bytes[4], version);
            let restored = decode(params, &bytes).unwrap();
            assert_eq!(
                restored.meta,
                Some(Metabolism {
                    len: cap as u32,
                    tapes: slots,
                    lens: Some(meta_lens),
                })
            );
            assert_eq!(restored.lineages, Some(lineages(params)));
            assert_eq!(restored.lens.is_some(), !lens.is_empty());
            assert_eq!(restored.stock.is_some(), !stock.is_empty());
        }
    }

    /// Grown lengths that do not count the cells, that leave a tape empty or overflow the
    /// cap, or that disagree with the live bytes, are not this world's.
    #[test]
    fn rejects_grown_metabolism_lengths_that_do_not_fit() {
        let params = params();
        let cells = vec![0u8; params.cell_count() * params.stride()];
        let cap = 16usize;
        let write = |meta_lens: &[u32], live: usize| {
            let slots = vec![1u8; params.cell_count() * cap];
            let mut bytes = encode_compressed_with_meta(
                &header(&params, 0),
                &metrics::compress(&cells),
                &lineages(&params),
                &[],
                &[],
                MetaTapes {
                    slots: &slots,
                    slot: cap,
                    lens: &vec![live as u32; params.cell_count()],
                },
            );
            let fields = HEADER_LEN + RELATIVE_FIELD_BYTES;
            let tapes_len = u64::from_le_bytes(bytes[fields..fields + 8].try_into().unwrap());
            let lens_at = bytes.len() - RELATIVE_LEN - {
                let at = fields + META_FIELD_BYTES;
                u64::from_le_bytes(bytes[at..at + 8].try_into().unwrap()) as usize
            };
            let tail = bytes.split_off(lens_at);
            let replaced = metrics::compress(&word_bytes(meta_lens));
            bytes.extend_from_slice(&replaced);
            bytes.extend_from_slice(&tail[tail.len() - RELATIVE_LEN..]);
            let at = fields + META_FIELD_BYTES;
            bytes[at..at + 8].copy_from_slice(&(replaced.len() as u64).to_le_bytes());
            assert!(tapes_len > 0);
            bytes
        };
        let cell_count = params.cell_count();
        assert!(decode(&params, &write(&vec![4; cell_count], 4)).is_ok());
        for (lens, field) in [
            (vec![4; cell_count - 1], "cell count"),
            (vec![0; cell_count], "meta_len"),
            (vec![cap as u32 + 1; cell_count], "meta_len"),
            (vec![5; cell_count], "cell count"),
        ] {
            assert!(
                matches!(
                    decode(&params, &write(&lens, 4)),
                    Err(SnapshotError::Mismatch { field: f }) if f == field
                ),
                "{field}"
            );
        }
    }

    /// Versions 9 to 11: the metabolism tapes travel beside every payload shape, and each
    /// shape's other payloads come back as the older version carries them.
    #[test]
    fn round_trips_the_metabolism_tapes_in_every_payload_shape() {
        let fixed = params();
        let stocked = Params {
            energy_influx: 4,
            energy_stock_cap: 64,
            ..params()
        };
        let ragged = Params {
            max_tape_len: 32,
            ..params()
        };
        let lens = vec![9u32; ragged.cell_count()];
        let stock = vec![5u32; stocked.cell_count()];
        for (params, lens, stock, version) in [
            (&fixed, &[][..], &[][..], VERSION_META),
            (&ragged, &lens[..], &[][..], VERSION_META_RAGGED),
            (&stocked, &[][..], &stock[..], VERSION_META_STOCKED),
        ] {
            let live = match lens.is_empty() {
                true => params.cell_count() * params.stride(),
                false => lens.iter().sum::<u32>() as usize,
            };
            let cells: Vec<u8> = (0..live).map(|at| at as u8).collect();
            let meta = tapes(params, 24);
            let bytes = encode_compressed_with_meta(
                &header(params, 40),
                &metrics::compress(&cells),
                &lineages(params),
                lens,
                stock,
                one_length(&meta, 24),
            );

            assert_eq!(bytes[4], version);
            let restored = decode(params, &bytes).unwrap();
            assert_eq!(
                restored.meta,
                Some(Metabolism {
                    len: 24,
                    tapes: meta,
                    lens: None,
                })
            );
            assert_eq!(restored.header.epoch, 40);
            assert_eq!(restored.lineages, Some(lineages(params)));
            assert_eq!(restored.lens.is_some(), !lens.is_empty());
            assert_eq!(restored.stock.is_some(), !stock.is_empty());
        }
    }

    /// The metabolism fields and payload are an addition: strip them and the version back
    /// to the older one, and what is left is the container written without them, byte for
    /// byte. A blob without them reads as a world without a metabolism tape.
    #[test]
    fn stripping_the_metabolism_section_leaves_the_older_container() {
        let params = Params {
            energy_influx: 4,
            energy_stock_cap: 64,
            ..params()
        };
        let payload = metrics::compress(&vec![3u8; params.cell_count() * params.stride()]);
        let stock = vec![5u32; params.cell_count()];
        let write = |meta: &[u8]| {
            encode_compressed_with_meta(
                &header(&params, 7),
                &payload,
                &lineages(&params),
                &[],
                &stock,
                one_length(meta, 16),
            )
        };
        let older = write(&[]);
        let meta = tapes(&params, 16);
        let carried = write(&meta);

        let fields = HEADER_LEN_V5 + RELATIVE_FIELD_BYTES;
        let tapes_len = u64::from_le_bytes(carried[fields..fields + 8].try_into().unwrap());
        assert_eq!(
            u32::from_le_bytes(carried[fields + 8..fields + 12].try_into().unwrap()),
            16
        );
        let relative_len = RELATIVE_LEN;
        let tapes_at = carried.len() - relative_len - tapes_len as usize;
        let mut stripped = carried[..fields].to_vec();
        stripped.extend_from_slice(&carried[fields + META_FIELD_BYTES..tapes_at]);
        stripped.extend_from_slice(&carried[carried.len() - relative_len..]);
        stripped[4] = VERSION_RELATIVE_STOCKED;
        assert_eq!(stripped, older);
        assert_eq!(decode(&params, &older).unwrap().meta, None);
    }

    /// A metabolism payload that does not hold one tape of the named length per cell, or
    /// names no length at all, is not this world's.
    #[test]
    fn rejects_metabolism_tapes_that_do_not_count_the_cells() {
        let params = params();
        let cells = vec![0u8; params.cell_count() * params.stride()];
        let write = |meta: &[u8]| {
            encode_compressed_with_meta(
                &header(&params, 0),
                &metrics::compress(&cells),
                &lineages(&params),
                &[],
                &[],
                one_length(meta, 8),
            )
        };
        let fields = HEADER_LEN + RELATIVE_FIELD_BYTES;

        let mut short = write(&tapes(&params, 8));
        short[fields + 8..fields + 12].copy_from_slice(&9u32.to_le_bytes());
        assert!(matches!(
            decode(&params, &short),
            Err(SnapshotError::Mismatch {
                field: "cell count"
            })
        ));

        for len in [0, META_LEN_MAX + 1] {
            let mut unnamed = write(&tapes(&params, 8));
            unnamed[fields + 8..fields + 12].copy_from_slice(&len.to_le_bytes());
            assert!(matches!(
                decode(&params, &unnamed),
                Err(SnapshotError::Mismatch { field: "meta_len" })
            ));
        }

        // The first overflows the two trailer lengths' sum, the second only that sum plus
        // the header's.
        for claimed in [u64::MAX, u64::MAX - RELATIVE_LEN as u64] {
            let mut overlong = write(&tapes(&params, 8));
            overlong[fields..fields + 8].copy_from_slice(&claimed.to_le_bytes());
            assert!(matches!(
                decode(&params, &overlong),
                Err(SnapshotError::Truncated)
            ));
        }
    }
}
