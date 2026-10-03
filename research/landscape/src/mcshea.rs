//! McShea's minimum (the out-compute entry, `docs/design_record.md`, "Descriptive and
//! offline"): the low percentile of per-cell max depth among the cells computing anything.
//! A driven trend raises it; a passive one need not. Every cell's tape is assayed under the
//! run's own instruction set, NAND and output slots on the six fixed case sets; a cell
//! computes where some class is credited on all six, and its max depth is the deepest class
//! so credited.

use crate::census::{cells, ranked};
use crate::depth::{depth_name, DepthScorer};
use crate::score::{assayed, par_map};
use life_engine::World;
use std::fmt::Write;

/// The percentiles printed, the first of them the minimum the entry reads.
pub const PERCENTILES: [(&str, usize); 4] =
    [("minimum (p10)", 10), ("p25", 25), ("p50", 50), ("p90", 90)];

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Minimum {
    pub epoch: u64,
    pub cells: u64,
    pub slots: usize,
    /// Each computing cell's max depth, ascending.
    pub depths: Vec<u32>,
    /// The classes credited on all six sets, summed over every cell.
    pub classes: u64,
}

/// The value at sorted index ⌊(n − 1) × percent / 100⌋, counting from 0 (the pilot's
/// rule), `None` for no values.
pub fn percentile(sorted: &[u32], percent: usize) -> Option<u32> {
    let last = sorted.len().checked_sub(1)?;
    Some(sorted[last * percent / 100])
}

pub fn minimum(world: &World, scorer: &DepthScorer) -> Minimum {
    let ranked = ranked(cells(world).map(|(x, y)| assayed(world, x, y)));
    let solids = par_map(&ranked, |(tape, _)| scorer.solid(tape));
    let mut depths = Vec::new();
    let mut classes = 0;
    for ((_, count), solid) in ranked.iter().zip(&solids) {
        classes += count * solid.classes.len() as u64;
        if let Some(depth) = solid.depth() {
            depths.extend(std::iter::repeat_n(depth, *count as usize));
        }
    }
    depths.sort_unstable();
    Minimum {
        epoch: world.epoch(),
        cells: world.params().cell_count() as u64,
        slots: scorer.slots(),
        depths,
        classes,
    }
}

impl Minimum {
    pub fn computing(&self) -> u64 {
        self.depths.len() as u64
    }

    /// The share of cells computing nothing.
    pub fn silent_share(&self) -> f64 {
        (self.cells - self.computing()) as f64 / self.cells as f64
    }

    /// The mean classes credited per cell, over every cell.
    pub fn repertoire(&self) -> f64 {
        self.classes as f64 / self.cells as f64
    }

    /// The 10th percentile, `None` (unread) where no cell computes.
    pub fn minimum(&self) -> Option<u32> {
        percentile(&self.depths, PERCENTILES[0].1)
    }

    fn rows(&self) -> Vec<(&'static str, String)> {
        let depth = |depth: Option<u32>| depth.map_or("unread".into(), depth_name);
        let mut rows = vec![
            ("epoch", self.epoch.to_string()),
            ("cells", self.cells.to_string()),
            ("slots", self.slots.to_string()),
            ("computing", self.computing().to_string()),
            ("silent share", format!("{:.4}", self.silent_share())),
            ("repertoire", format!("{:.4}", self.repertoire())),
        ];
        for (name, percent) in PERCENTILES {
            rows.push((name, depth(percentile(&self.depths, percent))));
        }
        rows.push(("max", depth(self.depths.last().copied())));
        rows
    }
}

/// The readings of one or more worlds in columns, each headed by its name.
pub fn render(worlds: &[(&str, &Minimum)]) -> String {
    let mut out = String::new();
    let columns: Vec<Vec<(&str, String)>> =
        worlds.iter().map(|(_, minimum)| minimum.rows()).collect();
    let _ = write!(out, "{:<14}", "");
    for (name, _) in worlds {
        let _ = write!(out, " {name:>12}");
    }
    out.push('\n');
    for (at, (label, _)) in columns[0].iter().enumerate() {
        let _ = write!(out, "{label:<14}");
        for column in &columns {
            let _ = write!(out, " {:>12}", column[at].1);
        }
        out.push('\n');
    }
    out.push_str(
        "\nper-cell max depth among the cells credited a class on all 6 fixed sets; \
         p at sorted index floor((n - 1) * p / 100)\n",
    );
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::depth::tests::{echo_then_xor4, out_compute_params};
    use crate::score::tests::stack_solver;

    fn blank() -> World {
        let params = out_compute_params();
        let mut world = World::new(&params, 3).unwrap();
        let zeros = vec![0u8; params.meta_len as usize];
        for (x, y) in cells(&world).collect::<Vec<_>>() {
            world.set_metabolism(x, y, &zeros);
        }
        world
    }

    fn padded(mut tape: Vec<u8>) -> Vec<u8> {
        tape.resize(out_compute_params().meta_len as usize, 0);
        tape
    }

    /// 20 of the 64 cells compute: depths 0, 0 | 1, 1, 1 | 2 × 5 | 4 × 6 | 5 × 4, so the
    /// indices 1, 4, 9 and 17 of the sorted 20 each sit on the low side of a step and any
    /// rounding up would read the next depth.
    fn planted() -> World {
        let mut world = blank();
        let plan = [(0, 2), (1, 3), (3, 5), (8, 6), (9, 4)];
        let mut at = 0u32;
        for (rung, cells) in plan {
            for _ in 0..cells {
                world.set_metabolism(at % 8, at / 8, &padded(stack_solver(rung)));
                at += 1;
            }
        }
        world
    }

    /// A random tape credited some class on four of the six sets and none on all six.
    const PARTIAL: &str = "!~,[[![<}<{";

    fn row(label: &str, values: &[&str]) -> String {
        let mut row = format!("{label:<14}");
        for value in values {
            row.push_str(&format!(" {value:>12}"));
        }
        row + "\n"
    }

    fn scorer() -> DepthScorer {
        DepthScorer::for_params(&out_compute_params()).unwrap()
    }

    #[test]
    fn the_percentiles_of_a_planted_world_are_read_at_the_pilots_indices() {
        let minimum = minimum(&planted(), &scorer());
        assert_eq!(minimum.cells, 64);
        assert_eq!(minimum.slots, 16);
        assert_eq!(minimum.computing(), 20);
        assert_eq!(minimum.silent_share(), 44.0 / 64.0);
        assert_eq!(minimum.repertoire(), 20.0 / 64.0);
        let read: Vec<Option<u32>> = PERCENTILES
            .iter()
            .map(|(_, percent)| percentile(&minimum.depths, *percent))
            .collect();
        assert_eq!(read, [Some(0), Some(1), Some(2), Some(5)]);
        assert_eq!(minimum.minimum(), Some(0));
        assert_eq!(minimum.depths.last(), Some(&5));
        let report = render(&[("world", &minimum)]);
        assert!(report.contains(&row("computing", &["20"])), "{report}");
        assert!(
            report.contains(&row("silent share", &["0.6875"])),
            "{report}"
        );
        assert!(report.contains(&row("repertoire", &["0.3125"])), "{report}");
    }

    #[test]
    fn the_index_is_the_floor_of_n_minus_one_times_the_percentile() {
        let ten: Vec<u32> = (0..10).collect();
        assert_eq!(percentile(&ten, 10), Some(0));
        assert_eq!(percentile(&ten, 25), Some(2));
        assert_eq!(percentile(&ten, 50), Some(4));
        assert_eq!(percentile(&ten, 90), Some(8));
        let eleven: Vec<u32> = (0..11).collect();
        assert_eq!(percentile(&eleven, 10), Some(1));
        assert_eq!(percentile(&[7], 10), Some(7));
        assert_eq!(percentile(&[7], 90), Some(7));
        assert_eq!(percentile(&[], 10), None);
    }

    #[test]
    fn a_world_where_no_cell_computes_reads_unread() {
        let minimum = minimum(&blank(), &scorer());
        assert_eq!(minimum.computing(), 0);
        assert_eq!(minimum.silent_share(), 1.0);
        assert_eq!(minimum.minimum(), None);
        let report = render(&[("world", &minimum)]);
        assert!(
            report.contains(&row("minimum (p10)", &["unread"])),
            "{report}"
        );
        assert!(report.contains(&row("max", &["unread"])), "{report}");
    }

    /// A cell computes only where a class is credited on all six sets: the tape credited a
    /// class on some sets and none on all six is silent, the one credited NOT on five and only
    /// ECHO beside it on the sixth computes at depth 1.
    #[test]
    fn a_cell_computes_only_where_all_six_sets_credit_a_class() {
        let scorer = scorer();
        let partial = padded(crate::tape::parse(PARTIAL, 0).unwrap());
        let credited_sets = (0..6)
            .filter(|set| scorer.on_set(&partial, *set).count() > 0)
            .count();
        assert_eq!(credited_sets, 4);
        assert!(scorer.solid(&partial).classes.is_empty());
        let agreeing = padded(crate::tape::parse("<{{![0!~.]{}[", 0).unwrap());
        assert_eq!(scorer.solid(&agreeing).depth(), Some(1));

        let mut world = blank();
        world.set_metabolism(0, 0, &partial);
        world.set_metabolism(1, 0, &agreeing);
        let minimum = minimum(&world, &scorer);
        assert_eq!(minimum.computing(), 1);
        assert_eq!(minimum.depths, [1]);
    }

    /// The engine's wider-assay tape: four slots read ECHO alone, the run's sixteen XOR4.
    #[test]
    fn sixteen_slots_read_a_planted_xor4_deeper_than_four() {
        let mut world = blank();
        world.set_metabolism(0, 0, &padded(echo_then_xor4()));
        let wide = minimum(&world, &scorer());
        assert_eq!(wide.depths, [12]);
        let four = DepthScorer::for_params(&life_engine::Params {
            task_max_outputs: 4,
            ..out_compute_params()
        })
        .unwrap();
        assert_eq!(minimum(&world, &four).depths, [0]);
    }

    #[test]
    fn two_worlds_print_side_by_side() {
        let (fifth, last) = (minimum(&blank(), &scorer()), minimum(&planted(), &scorer()));
        let report = render(&[("fifth", &fifth), ("last", &last)]);
        assert!(report.starts_with(&row("", &["fifth", "last"])), "{report}");
        assert!(report.contains(&row("computing", &["0", "20"])), "{report}");
        assert!(
            report.contains(&row("minimum (p10)", &["unread", "0"])),
            "{report}"
        );
    }
}
