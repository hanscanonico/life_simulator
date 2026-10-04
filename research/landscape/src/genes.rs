//! The genes machine read offline, for the genes-rise sweep: the gene-wise census and the
//! top solver's program side and load, on stored worlds whose metabolism tapes grow and
//! carry fidelity levels (snapshot versions 12 to 17). The definitions are the design
//! study's (`docs/studies/unassisted.md`, cited by section as the genes entries of
//! `docs/design_record.md` cite it): genes and essential genes §10.1, load-bearing genes
//! §10.1 and §10.5, `sub` and the load §11.1, the fidelity rate law §12.1, the minimum §13.4.
//!
//! The gene split and the assay are the engine's (`topless::genes`, `topless::assay_upto` at
//! the run's own output slots). A gene's classes are those credited on all six fixed sets,
//! which no engine credit holds, so the union and the essential grouping are applied here to
//! those class sets; a test holds the grouping to the engine's `topless::essential_genes`.

use crate::bearing::{substitutes, LOSING_SUBSTITUTES};
use crate::census::{cells, ranked};
use crate::depth::{depth_name, fixed_sets};
use crate::depth_census::a_tenth;
use crate::score::{assayed, par_map};
use crate::tape::{hex, show};
use life_engine::params::LogicNand;
use life_engine::topless::{self, Cases, Inputs};
use life_engine::{bff, fidelity, OpSet, Params, World};
use std::borrow::Cow;
use std::collections::{BTreeMap, HashMap, HashSet};
use std::fmt::Write;

/// The genes machine of one run: its ladder, instruction set, NAND, output slots and gene
/// length, on the six fixed sets.
#[derive(Debug, Clone)]
pub struct GeneScorer {
    inputs: Inputs,
    sets: Vec<Cases>,
    ops: OpSet,
    nand: LogicNand,
    slots: usize,
    gene_len: usize,
}

impl GeneScorer {
    /// The run's genes machine, `None` unless it reads the topless ladder as genes.
    pub fn for_params(params: &Params) -> Option<Self> {
        let inputs = params.tasks.depth_inputs()?;
        Some(Self {
            inputs,
            sets: fixed_sets(inputs),
            ops: params.op_set(),
            nand: params.logic_nand,
            slots: params.assay_slots(),
            gene_len: params.gene_len()?,
        })
    }

    pub fn gene_len(&self) -> usize {
        self.gene_len
    }

    /// One gene's classes credited on all six sets, ascending. A gene holding no emit byte
    /// is credited nothing and never run, as the engine's memo refuses it.
    pub fn gene_classes(&self, gene: &[u8]) -> Vec<u16> {
        if !gene.contains(&bff::EMIT) {
            return Vec::new();
        }
        let mut classes: Vec<u16> = Vec::new();
        for (at, cases) in self.sets.iter().enumerate() {
            let credit = topless::assay_upto(gene, cases, self.ops, self.nand, self.slots);
            if at == 0 {
                classes = credit.classes().collect();
            } else {
                classes.retain(|class| credit.classes().any(|held| held == *class));
            }
            if classes.is_empty() {
                break;
            }
        }
        classes.sort_unstable();
        classes
    }

    /// A tape's genes as the engine cuts them: at offsets 0, G, 2G…, the last zero-padded.
    pub fn genes<'t>(&self, tape: &'t [u8]) -> Vec<Cow<'t, [u8]>> {
        topless::genes(tape, self.gene_len).collect()
    }

    pub fn read(&self, tape: &[u8]) -> Genes {
        Genes(
            self.genes(tape)
                .iter()
                .map(|gene| self.gene_classes(gene))
                .collect(),
        )
    }
}

/// Each of a tape's genes' classes on all six sets, in gene order.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Genes(pub Vec<Vec<u16>>);

impl Genes {
    /// The classes the tape computes: the union of its genes' (§10.1).
    pub fn union(&self) -> Vec<u16> {
        let mut union: Vec<u16> = self.0.iter().flatten().copied().collect();
        union.sort_unstable();
        union.dedup();
        union
    }

    /// The genes computing at least one class.
    pub fn live(&self) -> usize {
        self.0.iter().filter(|classes| !classes.is_empty()).count()
    }

    /// Essential genes, §10.1 and `topless::essential_genes`: the genes grouped by the set
    /// of classes they compute, and a group counted where it computes a class no other
    /// group computes.
    pub fn essential(&self) -> usize {
        let mut groups: Vec<&Vec<u16>> = self.0.iter().filter(|set| !set.is_empty()).collect();
        groups.sort();
        groups.dedup();
        let mut groups_computing: HashMap<u16, usize> = HashMap::new();
        for class in groups.iter().flat_map(|group| group.iter()) {
            *groups_computing.entry(*class).or_default() += 1;
        }
        groups
            .iter()
            .filter(|group| group.iter().any(|class| groups_computing[class] == 1))
            .count()
    }

    /// How many genes compute each class, copies counted apart.
    fn genes_computing(&self) -> HashMap<u16, usize> {
        let mut counts = HashMap::new();
        for class in self.0.iter().flatten() {
            *counts.entry(*class).or_default() += 1;
        }
        counts
    }
}

/// The deepest class's minimal NAND count, `None` for none.
fn max_depth(inputs: Inputs, classes: &[u16]) -> Option<u32> {
    classes.iter().map(|class| inputs.depth(*class)).max()
}

/// The substitution rate a cell at fidelity `level` copies at, §12.1's law as the engine
/// applies it (`fidelity::rate`): `meta_rate` · 2^(−level/2). A world that carries no
/// levels copies at `meta_rate`, level 0's rate.
pub fn substitution_rate(params: &Params, level: Option<u32>) -> f64 {
    fidelity::rate(params.meta_rate, level.unwrap_or(0))
}

/// The ⌈n·p/100⌉-th smallest, the nearest rank the engine reads its fidelity percentiles
/// at (`fidelity_p10` and the rest).
fn nearest_rank<T: Copy>(sorted: &[T], percent: usize) -> Option<T> {
    (!sorted.is_empty()).then(|| sorted[(sorted.len() * percent).div_ceil(100).max(1) - 1])
}

fn percentiles<T: Copy + Ord>(mut values: Vec<T>) -> Option<[T; 4]> {
    values.sort_unstable();
    Some([
        nearest_rank(&values, 10)?,
        nearest_rank(&values, 50)?,
        nearest_rank(&values, 90)?,
        *values.last()?,
    ])
}

/// The top solver's program side and load (§10.1, §10.5, §11.1).
#[derive(Debug, Clone, PartialEq)]
pub struct Solver {
    pub tape: Vec<u8>,
    pub cells: u64,
    pub gene_len: usize,
    pub inputs: Inputs,
    pub genes: Genes,
    /// Per byte, how many of the 13 other symbols of the 14-symbol alphabet leave the tape
    /// fewer classes.
    pub losses: Vec<usize>,
    /// The fidelity level of the cells carrying it, their median at the nearest rank;
    /// `None` on a world that carries no levels.
    pub level: Option<u32>,
    pub rate: f64,
}

impl Solver {
    /// Reads `tape` under `scorer`: every byte substituted with each of the 13 other
    /// symbols, the mutant gene re-assayed alone and the tape's union re-taken.
    pub fn read(
        tape: &[u8],
        cells: u64,
        scorer: &GeneScorer,
        params: &Params,
        level: Option<u32>,
    ) -> Self {
        let genes = scorer.read(tape);
        let union = genes.union();
        let computing = genes.genes_computing();
        let cut = scorer.genes(tape);
        let positions: Vec<usize> = (0..tape.len()).collect();
        let losses = par_map(&positions, |at| {
            let gene = at / scorer.gene_len;
            let own = &genes.0[gene];
            let kept: Vec<u16> = union
                .iter()
                .copied()
                .filter(|class| !own.contains(class) || computing[class] > 1)
                .collect();
            let mut mutant = cut[gene].to_vec();
            let offset = at % scorer.gene_len;
            substitutes(tape[*at])
                .filter(|symbol| {
                    mutant[offset] = *symbol;
                    let gained = scorer.gene_classes(&mutant);
                    let mut after = kept.clone();
                    after.extend(gained);
                    after.sort_unstable();
                    after.dedup();
                    after.len() < union.len()
                })
                .count()
        });
        Self {
            tape: tape.to_vec(),
            cells,
            gene_len: scorer.gene_len,
            inputs: scorer.inputs,
            genes,
            losses,
            level,
            rate: substitution_rate(params, level),
        }
    }

    /// Count-bearing bytes (§10.1, `nbc`): the positions where at least 7 of the 13 other
    /// symbols leave the tape fewer classes.
    pub fn count_bearing(&self) -> Vec<usize> {
        (0..self.losses.len())
            .filter(|at| self.losses[*at] >= LOSING_SUBSTITUTES)
            .collect()
    }

    /// Load-bearing genes (§10.1, `bseg`): the genes holding a count-bearing byte.
    pub fn load_bearing_genes(&self) -> Vec<usize> {
        let mut genes: Vec<usize> = self
            .count_bearing()
            .iter()
            .map(|at| at / self.gene_len)
            .collect();
        genes.dedup();
        genes
    }

    /// Distinct bodies (§10.1, `bbod`): the load-bearing genes' distinct cores, a core being
    /// a gene's bytes from its first count-bearing byte to its last.
    pub fn distinct_bodies(&self) -> usize {
        let bearing = self.count_bearing();
        let cores: HashSet<&[u8]> = self
            .load_bearing_genes()
            .iter()
            .map(|gene| {
                let mine: Vec<usize> = bearing
                    .iter()
                    .copied()
                    .filter(|at| at / self.gene_len == *gene)
                    .collect();
                &self.tape[mine[0]..=mine[mine.len() - 1]]
            })
            .collect();
        cores.len()
    }

    /// `sub` (§11.1): over the tape's bytes, the share of the 14 draws of a substitution
    /// (the byte's own symbol among them) that leave the tape fewer classes, summed. A byte
    /// whose 13 others all lose a class counts 13/14.
    pub fn sub(&self) -> f64 {
        self.losses.iter().sum::<usize>() as f64 / 14.0
    }

    /// The substitution load per epoch, rate × `sub`, at the solver's own rate; §11.1's
    /// U_sub per generation is this times the generation time T_gen.
    pub fn load(&self) -> f64 {
        self.rate * self.sub()
    }

    pub fn render(&self) -> String {
        let mut out = String::new();
        let union = self.genes.union();
        let depth = max_depth(self.inputs, &union).map_or("-".into(), depth_name);
        let level = self
            .level
            .map_or("none (level 0's rate, meta_rate)".into(), |level| {
                level.to_string()
            });
        let _ = writeln!(
            out,
            "  cells {} length {} genes {} live {} essential {} classes {} depth {depth}",
            self.cells,
            self.tape.len(),
            self.genes.0.len(),
            self.genes.live(),
            self.genes.essential(),
            union.len(),
        );
        let _ = writeln!(
            out,
            "  count-bearing bytes {}; load-bearing genes {} (distinct bodies {})",
            self.count_bearing().len(),
            self.load_bearing_genes().len(),
            self.distinct_bodies()
        );
        let _ = writeln!(
            out,
            "  sub {:.2}; fidelity level {level}, rate {:.6e}; U_sub = rate x sub {:.6} per epoch \
             (x T_gen for a generation)",
            self.sub(),
            self.rate,
            self.load()
        );
        let computing = self.genes.genes_computing();
        let bearing = self.count_bearing();
        for (gene, classes) in self.genes.0.iter().enumerate() {
            let bears = bearing
                .iter()
                .filter(|at| *at / self.gene_len == gene)
                .count();
            if classes.is_empty() && bears == 0 {
                continue;
            }
            let from = gene * self.gene_len;
            let to = (from + self.gene_len).min(self.tape.len());
            let alone = classes.iter().filter(|class| computing[class] == 1).count();
            let _ = writeln!(
                out,
                "  gene {gene:3}: classes {:3} alone {:3} count-bearing {:2}  {}",
                classes.len(),
                alone,
                bears,
                show(&self.tape[from..to])
            );
        }
        let _ = writeln!(out, "  {}\n  {}", show(&self.tape), hex(&self.tape));
        out
    }
}

/// The fidelity levels over all cells.
#[derive(Debug, Clone, PartialEq)]
pub struct Levels {
    pub cells: BTreeMap<u32, u64>,
    pub mean: f64,
    /// p10, p50, p90 at the nearest rank, and the highest.
    pub percentiles: [u32; 4],
}

/// The gene-wise census of one stored world (§10.1's census and §13.4's minimum, over all
/// cells, on the six fixed sets).
#[derive(Debug, Clone, PartialEq)]
pub struct GeneCensus {
    pub epoch: u64,
    pub cells: u64,
    pub gene_len: usize,
    pub inputs: Inputs,
    pub distinct_tapes: usize,
    pub distinct_genes: usize,
    pub silent: u64,
    pub classes_mean: f64,
    /// Classes per computing cell: p10 (the minimum's repertoire), p50, p90, the most.
    pub classes: Option<[usize; 4]>,
    /// Per-cell max depth over computing cells: p10 (McShea's minimum), p50, p90, deepest.
    pub max_depth: Option<[u32; 4]>,
    /// Classes credited to at least a tenth of the cells.
    pub classes_held: usize,
    /// The deepest of them.
    pub depth_held: Option<u32>,
    /// The most essential genes at least a tenth of all cells carry: the engine's
    /// `genes_essential_held` read over every cell rather than a sample of 256.
    pub essential_held: usize,
    /// Essential genes per computing cell: p10, p50, p90, the most.
    pub essential: Option<[usize; 4]>,
    pub length_mean: f64,
    /// Live length over all cells: p10, p50, p90, the longest.
    pub length: [usize; 4],
    pub levels: Option<Levels>,
    pub top: Option<Solver>,
}

impl GeneCensus {
    pub fn read(world: &World, scorer: &GeneScorer) -> Self {
        let params = world.params();
        let cell_count = params.cell_count() as u64;
        let ranked = ranked(cells(world).map(|(x, y)| assayed(world, x, y)));

        let mut distinct: Vec<Vec<u8>> = ranked
            .iter()
            .flat_map(|(tape, _)| scorer.genes(tape).into_iter().map(Cow::into_owned))
            .collect::<HashSet<Vec<u8>>>()
            .into_iter()
            .collect();
        distinct.sort_unstable();
        let gene_classes: HashMap<&[u8], Vec<u16>> = distinct
            .iter()
            .map(Vec::as_slice)
            .zip(par_map(&distinct, |gene| scorer.gene_classes(gene)))
            .collect();
        let readings: Vec<Genes> = ranked
            .iter()
            .map(|(tape, _)| {
                Genes(
                    scorer
                        .genes(tape)
                        .iter()
                        .map(|gene| gene_classes[gene.as_ref()].clone())
                        .collect(),
                )
            })
            .collect();

        let inputs = scorer.inputs;
        let mut silent = 0;
        let mut classes_total = 0u64;
        let mut computing_classes = Vec::new();
        let mut computing_depths = Vec::new();
        let mut computing_essential = Vec::new();
        let mut essential_all = Vec::new();
        let mut credited: BTreeMap<u16, u64> = BTreeMap::new();
        for ((_, count), genes) in ranked.iter().zip(&readings) {
            let union = genes.union();
            let essential = genes.essential();
            classes_total += union.len() as u64 * count;
            essential_all.extend(std::iter::repeat_n(essential, *count as usize));
            let Some(depth) = max_depth(inputs, &union) else {
                silent += count;
                continue;
            };
            for class in &union {
                *credited.entry(*class).or_default() += count;
            }
            let many = *count as usize;
            computing_classes.extend(std::iter::repeat_n(union.len(), many));
            computing_depths.extend(std::iter::repeat_n(depth, many));
            computing_essential.extend(std::iter::repeat_n(essential, many));
        }
        let held: Vec<u16> = credited
            .iter()
            .filter(|(_, cells)| a_tenth(**cells, cell_count))
            .map(|(class, _)| *class)
            .collect();
        essential_all.sort_unstable_by(|a, b| b.cmp(a));
        let tenth = cell_count.div_ceil(10) as usize;
        let classes = percentiles(computing_classes);

        let lengths: Vec<usize> = cells(world)
            .map(|(x, y)| assayed(world, x, y).len())
            .collect();
        let length_mean = lengths.iter().sum::<usize>() as f64 / lengths.len() as f64;
        let levels: Vec<u32> = cells(world)
            .filter_map(|(x, y)| world.fidelity(x, y).map(u32::from))
            .collect();

        let top = classes.map(|[_, _, p90, _]| {
            let (tape, count) = ranked
                .iter()
                .zip(&readings)
                .find(|(_, genes)| genes.union().len() >= p90)
                .map(|(row, _)| *row)
                .expect("a cell computing the 90th percentile's classes");
            let mut own: Vec<u32> = cells(world)
                .filter(|(x, y)| assayed(world, *x, *y) == tape)
                .filter_map(|(x, y)| world.fidelity(x, y).map(u32::from))
                .collect();
            own.sort_unstable();
            Solver::read(tape, count, scorer, params, nearest_rank(&own, 50))
        });

        Self {
            epoch: world.epoch(),
            cells: cell_count,
            gene_len: scorer.gene_len,
            inputs,
            distinct_tapes: ranked.len(),
            distinct_genes: distinct.len(),
            silent,
            classes_mean: classes_total as f64 / cell_count as f64,
            classes,
            max_depth: percentiles(computing_depths),
            classes_held: held.len(),
            depth_held: max_depth(inputs, &held),
            essential_held: essential_all.get(tenth - 1).copied().unwrap_or(0),
            essential: percentiles(computing_essential),
            length_mean,
            length: percentiles(lengths).unwrap_or_default(),
            levels: Self::levels(levels),
            top,
        }
    }

    fn levels(levels: Vec<u32>) -> Option<Levels> {
        let mut cells: BTreeMap<u32, u64> = BTreeMap::new();
        for level in &levels {
            *cells.entry(*level).or_default() += 1;
        }
        let mean = levels.iter().map(|level| f64::from(*level)).sum::<f64>() / levels.len() as f64;
        Some(Levels {
            cells,
            mean,
            percentiles: percentiles(levels)?,
        })
    }

    pub fn render(&self) -> String {
        let mut out = String::new();
        let quartet = |values: Option<[usize; 4]>| {
            values.map_or("-".into(), |[p10, p50, p90, most]| {
                format!("p10 {p10} p50 {p50} p90 {p90} max {most}")
            })
        };
        let ladder = match self.inputs {
            Inputs::Three => "logic3",
            Inputs::Four => "logic4",
        };
        let _ = writeln!(
            out,
            "epoch {} cells {} ladder {ladder} genes of {} bytes; distinct metabolism tapes {} \
             genes {}",
            self.epoch, self.cells, self.gene_len, self.distinct_tapes, self.distinct_genes
        );
        let _ = writeln!(
            out,
            "\ngene-wise census, a gene's classes those credited on all 6 fixed sets, a cell's \
             the union of its genes':"
        );
        let _ = writeln!(
            out,
            "  silent cells {} ({:.4}); classes per cell {:.3}",
            self.silent,
            self.silent as f64 / self.cells as f64,
            self.classes_mean
        );
        let _ = writeln!(
            out,
            "  classes held by a tenth {}; depth held by a tenth {}",
            self.classes_held,
            self.depth_held.map_or("-".into(), depth_name)
        );
        let _ = writeln!(
            out,
            "  essential genes held by a tenth {}",
            self.essential_held
        );
        let _ = writeln!(
            out,
            "  classes per computing cell: {}",
            quartet(self.classes)
        );
        let _ = writeln!(
            out,
            "  max depth per computing cell: {}",
            quartet(
                self.max_depth
                    .map(|depths| depths.map(|depth| depth as usize))
            )
        );
        let _ = writeln!(
            out,
            "  the minimum: classes p10 {}, max depth p10 {}",
            self.classes.map_or("-".into(), |c| c[0].to_string()),
            self.max_depth.map_or("-".into(), |d| d[0].to_string())
        );
        let _ = writeln!(
            out,
            "  essential genes per computing cell: {}",
            quartet(self.essential)
        );
        let [p10, p50, p90, longest] = self.length;
        let _ = writeln!(
            out,
            "  length: mean {:.1} p10 {p10} p50 {p50} p90 {p90} max {longest}",
            self.length_mean
        );
        let _ = match &self.levels {
            Some(levels) => {
                let [p10, p50, p90, most] = levels.percentiles;
                let cells: Vec<String> = levels
                    .cells
                    .iter()
                    .map(|(level, cells)| format!("{level}:{cells}"))
                    .collect();
                writeln!(
                    out,
                    "  fidelity: mean {:.2} p10 {p10} p50 {p50} p90 {p90} max {most}; cells by \
                     level {}",
                    levels.mean,
                    cells.join(" ")
                )
            }
            None => writeln!(out, "  fidelity: no levels carried"),
        };
        let _ = match &self.top {
            Some(top) => writeln!(
                out,
                "\ntop solver, the commonest tape among the cells computing the computing \
                 cells' p90 of classes or more:\n{}",
                top.render().trim_end()
            ),
            None => writeln!(out, "\nno computing cell: no top solver"),
        };
        out
    }
}

/// The keys the two worlds are compared on, each as a number, in print order.
fn keys(census: &GeneCensus) -> Vec<(&'static str, Option<f64>)> {
    let top = census.top.as_ref();
    let as_f64 = |value: usize| value as f64;
    vec![
        ("classes held by a tenth", Some(as_f64(census.classes_held))),
        (
            "essential genes held by a tenth",
            Some(as_f64(census.essential_held)),
        ),
        (
            "classes per computing cell p10 (the minimum)",
            census.classes.map(|c| as_f64(c[0])),
        ),
        (
            "classes per computing cell p50",
            census.classes.map(|c| as_f64(c[1])),
        ),
        (
            "classes per computing cell p90",
            census.classes.map(|c| as_f64(c[2])),
        ),
        (
            "max depth p10 (the minimum)",
            census.max_depth.map(|d| f64::from(d[0])),
        ),
        ("depth held by a tenth", census.depth_held.map(f64::from)),
        ("mean length", Some(census.length_mean)),
        (
            "fidelity p50",
            census
                .levels
                .as_ref()
                .map(|levels| f64::from(levels.percentiles[1])),
        ),
        (
            "top: count-bearing bytes",
            top.map(|top| as_f64(top.count_bearing().len())),
        ),
        (
            "top: load-bearing genes",
            top.map(|top| as_f64(top.load_bearing_genes().len())),
        ),
        ("top: sub", top.map(Solver::sub)),
        (
            "top: fidelity level",
            top.and_then(|top| top.level.map(f64::from)),
        ),
        ("top: U_sub per epoch", top.map(Solver::load)),
    ]
}

/// The fifth-decile world against the last, each read in full, then key by key.
pub fn compare(fifth: &GeneCensus, last: &GeneCensus) -> String {
    let shown = |value: Option<f64>| match value {
        None => "-".to_string(),
        Some(value) if value.fract() == 0.0 => format!("{value:.0}"),
        Some(value) if value.abs() < 0.1 => format!("{value:.6}"),
        Some(value) => format!("{value:.2}"),
    };
    let mut out = format!(
        "fifth-decile world\n{}\nlast world\n{}\nfifth-decile world (epoch {}) to last (epoch {}):\n",
        fifth.render(),
        last.render(),
        fifth.epoch,
        last.epoch
    );
    for ((key, before), (_, after)) in keys(fifth).into_iter().zip(keys(last)) {
        let change = before.zip(after).map(|(before, after)| after - before);
        let _ = writeln!(
            out,
            "  {key:46} {:>12} -> {:>12}  change {}",
            shown(before),
            shown(after),
            change.map_or("-".into(), |change| {
                let sign = if change > 0.0 { "+" } else { "" };
                format!("{sign}{}", shown(Some(change)))
            })
        );
    }
    out
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use crate::tape;
    use life_engine::params::{EnergyPayer, MetaDraw, MetaSeed, Predation, Tasks};
    use life_engine::topless::Credit;
    use life_engine::{rng, Params};

    /// §7's 12-class loop, §7.3's tandem variant and the ECHO (`topless::tests`' own).
    pub const LOOP: &str = "<<<<[!{~!~]";
    pub const TANDEM: &str = "<<<<[!{~!{~!~]";
    pub const ECHO: &str = "<!";

    /// The study's §13.3 bundle on an 8×8 world: strict out-count on the union of 32-byte
    /// genes, the channel growing by duplication and deletion to 256, staged fidelity.
    pub fn genes_params() -> Params {
        Params {
            width: 8,
            height: 8,
            energy_payer: EnergyPayer::Initiator,
            energy_influx: 1024,
            energy_stock_cap: 65_536,
            tasks: Tasks::Logic4,
            task_every: 8,
            task_reward: 0,
            task_max_outputs: 16,
            logic_nand: LogicNand::Stack,
            meta_len: 32,
            meta_rate: 8.0 / 8192.0,
            meta_draw: MetaDraw::Isa,
            meta_seed: MetaSeed::OwnTape,
            meta_max_len: 256,
            meta_dup: 0.05,
            meta_del: 0.05,
            meta_genes: 32,
            meta_fid_max: 16,
            meta_fid_rate: 0.05,
            meta_fid_alpha: 0.03,
            predation: Predation::Count,
            predation_transfer: 8192,
            ..Params::default()
        }
    }

    pub fn scorer() -> GeneScorer {
        GeneScorer::for_params(&genes_params()).unwrap()
    }

    /// `pieces` laid at offsets 0, 32, 64…, zero between them, the last cut at its end.
    pub fn laid(pieces: &[&str]) -> Vec<u8> {
        let mut tape = Vec::new();
        for piece in pieces {
            tape.extend(tape::parse(piece, 32).unwrap());
        }
        tape
    }

    #[test]
    fn the_bundle_is_valid_and_reads_genes_and_levels() {
        let params = genes_params();
        assert_eq!(params.validate(), Ok(()));
        assert!(params.carries_fidelity());
        assert_eq!(params.gene_len(), Some(32));
        let fixed = Params {
            meta_max_len: 0,
            meta_dup: 0.0,
            meta_del: 0.0,
            meta_genes: 0,
            meta_fid_max: 0,
            meta_fid_rate: 0.0,
            meta_fid_alpha: 0.0,
            ..params
        };
        assert!(GeneScorer::for_params(&fixed).is_none());
    }

    /// The study's §10.1 checks: the loop alone and twice, and beside its tandem variant,
    /// whose classes it adds rather than swaps.
    #[test]
    fn planted_genes_read_their_classes_union_and_essential_count() {
        let scorer = scorer();
        let alone = scorer.read(&laid(&[LOOP]));
        let loop_classes = alone.union().len();
        assert_eq!(loop_classes, 12);
        assert_eq!((alone.0.len(), alone.live(), alone.essential()), (1, 1, 1));

        let twice = scorer.read(&laid(&[LOOP, LOOP]));
        assert_eq!(twice.union().len(), loop_classes);
        assert_eq!((twice.live(), twice.essential()), (2, 1));

        let pair = scorer.read(&laid(&[LOOP, TANDEM]));
        let tandem = scorer.read(&laid(&[TANDEM])).union();
        let shared = alone
            .union()
            .iter()
            .filter(|class| tandem.contains(class))
            .count();
        assert_eq!(pair.union().len(), loop_classes + tandem.len() - shared);
        assert!(pair.union().len() > loop_classes.max(tandem.len()));
        assert_eq!(pair.essential(), 2);
        assert_eq!(pair, scorer.read(&laid(&[LOOP, TANDEM])));
        assert_eq!(scorer.read(&laid(&[TANDEM, LOOP])).essential(), 2);

        let silent = scorer.read(&laid(&["<<{~", "", "<<>>"]));
        assert_eq!(
            (silent.0.len(), silent.live(), silent.essential()),
            (3, 0, 0)
        );
        assert!(silent.union().is_empty());
    }

    /// A gene runs alone on its own segment: what follows it never changes its classes, and
    /// a partial last gene reads zero-padded.
    #[test]
    fn a_gene_reads_alone_and_the_last_is_padded() {
        let scorer = scorer();
        let full = laid(&[LOOP, ECHO]);
        let cut = &full[..32 + 2];
        assert_eq!(scorer.read(cut), scorer.read(&full));
        let mut junk = laid(&[LOOP]);
        junk.extend(b"]]]][[[[{<~!".iter());
        assert_eq!(scorer.read(&junk).0[0], scorer.read(&laid(&[LOOP])).0[0]);
    }

    /// The §10.1 echo + loop case: the loop emits x too, so the ECHO gene adds no class of
    /// its own and counts nothing; the grouping agrees with the engine's on one set's
    /// credits of the same tapes.
    #[test]
    fn essential_genes_group_as_the_engine_groups() {
        let scorer = scorer();
        let echo_loop = scorer.read(&laid(&[LOOP, "", ECHO, LOOP]));
        assert_eq!(echo_loop.live(), 3);
        assert_eq!(echo_loop.essential(), 1);
        assert_eq!(scorer.read(&laid(&[TANDEM, LOOP, ECHO])).essential(), 2);

        let synthetic = |sets: &[&[u16]]| Genes(sets.iter().map(|set| set.to_vec()).collect());
        assert_eq!(synthetic(&[]).essential(), 0);
        assert_eq!(synthetic(&[&[3, 5], &[3, 5], &[]]).essential(), 1);
        assert_eq!(synthetic(&[&[3, 5], &[3, 5, 9]]).essential(), 1);
        assert_eq!(synthetic(&[&[3, 5], &[9]]).essential(), 2);
        assert_eq!(synthetic(&[&[3, 5], &[5, 7], &[3, 7]]).essential(), 0);

        let cases = Cases::draw(Inputs::Four, &mut rng::seeded(1, 2, 3));
        let mut draw = rng::seeded(7, 0, 0);
        let pieces = [LOOP, TANDEM, ECHO, "", "<{~!", "<<{~!", "{<~!"];
        for _ in 0..200 {
            let count = 1 + rng::below(&mut draw, 6) as usize;
            let chosen: Vec<&str> = (0..count)
                .map(|_| pieces[rng::below(&mut draw, pieces.len() as u64) as usize])
                .collect();
            let tape = laid(&chosen);
            let credits: Vec<Credit> = scorer
                .genes(&tape)
                .iter()
                .map(|gene| topless::assay_upto(gene, &cases, OpSet::ALL, LogicNand::Stack, 16))
                .collect();
            let mut sets: Vec<Vec<u16>> = credits
                .iter()
                .map(|credit| credit.classes().collect())
                .collect();
            for set in &mut sets {
                set.sort_unstable();
            }
            assert_eq!(
                Genes(sets).essential() as u32,
                topless::essential_genes(&credits),
                "{chosen:?}"
            );
        }
    }

    #[test]
    fn the_rate_law_halves_every_two_levels() {
        let params = genes_params();
        let base = params.meta_rate;
        assert_eq!(substitution_rate(&params, None), base);
        assert_eq!(substitution_rate(&params, Some(0)), base);
        let one = substitution_rate(&params, Some(1));
        assert!((one - base / 2f64.sqrt()).abs() < 1e-18);
        assert_eq!(substitution_rate(&params, Some(16)), base / 256.0);
        assert_eq!(
            substitution_rate(&params, Some(16)),
            1.0 / 8192.0 / 32.0,
            "x8 at level 0 is x1/32 at level 16"
        );
    }

    #[test]
    fn the_nearest_rank_is_the_engines() {
        let levels: Vec<u32> = (1..=256).collect();
        assert_eq!(nearest_rank(&levels, 10), Some(26));
        assert_eq!(nearest_rank(&levels, 50), Some(128));
        assert_eq!(nearest_rank(&levels, 90), Some(231));
        assert_eq!(nearest_rank(&[7u32], 10), Some(7));
        assert_eq!(nearest_rank::<u32>(&[], 50), None);
    }

    /// The fast reading of a substitution (the mutant gene re-assayed, the other genes'
    /// classes kept) against the whole mutant tape re-read.
    fn losses_by_rereading(tape: &[u8], scorer: &GeneScorer) -> Vec<usize> {
        let total = scorer.read(tape).union().len();
        (0..tape.len())
            .map(|at| {
                substitutes(tape[at])
                    .filter(|symbol| {
                        let mut mutant = tape.to_vec();
                        mutant[at] = *symbol;
                        scorer.read(&mutant).union().len() < total
                    })
                    .count()
            })
            .collect()
    }

    /// `sub` and the program side on known solvers (§10.1's checks, §11.1's `sub`): the
    /// loop alone bears its classes on its code and nowhere in its padding; two copies
    /// cover each other, so neither bears anything; beside its tandem variant both genes
    /// bear, with distinct bodies.
    #[test]
    fn sub_and_the_bearing_genes_of_known_solvers() {
        let scorer = scorer();
        let params = genes_params();
        let read = |pieces: &[&str]| {
            let tape = laid(pieces);
            let solver = Solver::read(&tape, 1, &scorer, &params, Some(2));
            assert_eq!(
                solver.losses,
                losses_by_rereading(&tape, &scorer),
                "{pieces:?}"
            );
            solver
        };

        let alone = read(&[LOOP]);
        let bearing = alone.count_bearing();
        assert!(!bearing.is_empty() && bearing.iter().all(|at| *at < LOOP.len()));
        assert!(alone.losses[LOOP.len()..].iter().all(|lost| *lost < 7));
        assert_eq!(alone.load_bearing_genes(), [0]);
        assert_eq!(alone.distinct_bodies(), 1);
        assert_eq!(
            bearing.len(),
            11,
            "every byte of the loop bears its classes"
        );
        assert_eq!(alone.sub(), 139.0 / 14.0);
        assert_eq!(alone.rate, params.meta_rate / 2.0);
        assert_eq!(alone.load(), alone.rate * alone.sub());

        let twice = read(&[LOOP, LOOP]);
        assert_eq!(twice.sub(), 0.0, "each copy covers the other");
        assert!(twice.count_bearing().is_empty() && twice.load_bearing_genes().is_empty());

        let pair = read(&[LOOP, TANDEM]);
        assert_eq!(pair.load_bearing_genes(), [0, 1]);
        assert_eq!(pair.distinct_bodies(), 2);
        assert!(pair.sub() > alone.sub());
        let in_gene = |gene: usize| {
            pair.count_bearing()
                .iter()
                .filter(|at| **at / 32 == gene)
                .count()
        };
        assert_eq!(
            (in_gene(0), in_gene(1)),
            (11, 14),
            "the study's §10.1 check"
        );
        assert_eq!(pair.genes.union().len(), 26);
        assert_eq!(pair.sub(), 321.0 / 14.0);
        let rendered = pair.render();
        assert!(
            rendered.contains("load-bearing genes 2 (distinct bodies 2)"),
            "{rendered}"
        );
    }

    /// A planted 8×8 world of genes, lengths and levels, stored and read back: the census
    /// reads it as laid, and the stored world reads as the live one.
    fn planted() -> World {
        let params = genes_params();
        let mut world = World::new(&params, 3).unwrap();
        let pair = laid(&[LOOP, TANDEM]);
        let alone = laid(&[LOOP]);
        let echo = tape::parse(ECHO, 0).unwrap();
        for y in 0..8 {
            for x in 0..8 {
                let (tape, level) = match y {
                    0 => (pair.clone(), 4),
                    1 | 2 => (alone.clone(), 2),
                    3 => (echo.clone(), 1),
                    _ => (vec![0u8; 40], 0),
                };
                world.set_metabolism(x, y, &tape);
                world.set_fidelity(x, y, level);
            }
        }
        world
    }

    #[test]
    fn the_census_reads_a_planted_world_and_its_top_solver() {
        let scorer = scorer();
        let world = planted();
        let census = GeneCensus::read(&world, &scorer);
        let pair = scorer.read(&laid(&[LOOP, TANDEM])).union().len();
        assert_eq!((census.cells, census.silent), (64, 32));
        assert_eq!(census.distinct_tapes, 4);
        assert_eq!(
            census.classes_held, pair,
            "the tandem's own classes are on 8 of 64"
        );
        assert_eq!(census.essential_held, 2, "the 7th of 64 cells holds 2");
        assert_eq!(census.classes, Some([1, 12, pair, pair]));
        assert_eq!(census.essential, Some([1, 1, 2, 2]));
        assert_eq!(
            census.max_depth.map(|d| d[0]),
            Some(0),
            "the ECHO is depth 0"
        );
        assert_eq!(census.length, [2, 40, 64, 64]);
        let levels = census.levels.as_ref().unwrap();
        assert_eq!(levels.percentiles, [0, 0, 4, 4]);
        assert_eq!(
            levels.cells,
            BTreeMap::from([(0, 32), (1, 8), (2, 16), (4, 8)])
        );
        let top = census.top.as_ref().unwrap();
        assert_eq!((top.tape.clone(), top.cells), (laid(&[LOOP, TANDEM]), 8));
        assert_eq!(top.level, Some(4));
        assert_eq!(top.rate, genes_params().meta_rate / 4.0);
        let rendered = census.render();
        assert!(
            rendered.contains("essential genes held by a tenth 2"),
            "{rendered}"
        );
        assert!(rendered.contains("fidelity: mean"), "{rendered}");
    }

    #[test]
    fn a_stored_world_with_levels_reads_as_the_live_one() {
        let scorer = scorer();
        let world = planted();
        let blob = world.snapshot();
        let stored = crate::stored::Stored {
            params: genes_params(),
            blob,
        };
        let back = stored.world(0).unwrap();
        assert_eq!(
            GeneCensus::read(&back, &scorer),
            GeneCensus::read(&world, &scorer)
        );
    }

    /// A growing channel without levels (versions 12 to 14) reads the rate at `meta_rate`.
    #[test]
    fn a_world_without_levels_reads_the_base_rate() {
        let params = Params {
            meta_fid_max: 0,
            meta_fid_rate: 0.0,
            meta_fid_alpha: 0.0,
            ..genes_params()
        };
        let scorer = GeneScorer::for_params(&params).unwrap();
        let mut world = World::new(&params, 3).unwrap();
        for y in 0..8 {
            for x in 0..8 {
                world.set_metabolism(x, y, &laid(&[LOOP]));
            }
        }
        let stored = crate::stored::Stored {
            params: params.clone(),
            blob: world.snapshot(),
        };
        let census = GeneCensus::read(&stored.world(0).unwrap(), &scorer);
        assert_eq!(census.levels, None);
        let top = census.top.as_ref().unwrap();
        assert_eq!((top.level, top.rate), (None, params.meta_rate));
        assert!(census.render().contains("fidelity: no levels carried"));
    }

    #[test]
    fn two_worlds_compare_key_by_key() {
        let scorer = scorer();
        let last = GeneCensus::read(&planted(), &scorer);
        let mut early = planted();
        for x in 0..8 {
            early.set_metabolism(x, 0, &laid(&[LOOP]));
        }
        let fifth = GeneCensus::read(&early, &scorer);
        let report = compare(&fifth, &last);
        assert!(report.starts_with("fifth-decile world\n"));
        let row = report
            .lines()
            .find(|line| line.contains("essential genes held by a tenth") && line.contains("->"))
            .unwrap();
        assert!(row.contains("1 ->") && row.ends_with("change +1"), "{row}");
        assert!(report.contains("top: load-bearing genes"));
    }
}
