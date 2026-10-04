use landscape::bearing::{load_bearing, rise_code};
use landscape::depth::{depth_name, DepthScorer};
use landscape::depth_census::{self, DepthCensus};
use landscape::score::{assayed_len, rung_index, Rungs, Scorer, DEEP};
use landscape::stored::{read_params, Stored};
use landscape::{census, mcshea, paths, plant, tape, trace};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "\
landscape census   --snapshot WORLD.lsnp --params PARAMS.json [--top 8]
landscape loadbearing TAPE --params PARAMS.json [--depth D]
landscape loadbearing --snapshot WORLD.lsnp --params PARAMS.json
landscape loadbearing [--first W.lsnp] --fifth W.lsnp --last W.lsnp --params PARAMS.json
landscape mcshea   --snapshot WORLD.lsnp --params PARAMS.json
landscape mcshea   --fifth W.lsnp --last W.lsnp --params PARAMS.json
landscape distance A B --params PARAMS.json
landscape paths    START --params PARAMS.json [--k 3] [--window LEN] [--rungs xor,equ] [--examples 4]
landscape plant    --snapshot END.lsnp --params PARAMS.json --deep TAPE --rung xor|equ
                   [--source WORLD.lsnp | --replicating TAPE] [--seeds 2001,2002,2003]
                   [--epochs 2000] [--every 500] [--side 4]
landscape trace    TAPE --params PARAMS.json --rung xor|equ [--lines 60]

On a logic3 or logic4 run, `census` reads the topless ladder and ignores --top.
`loadbearing` and `mcshea` read logic3 and logic4 runs only, over the run's own
task_max_outputs output slots.

A TAPE is `hex:` and two digits a byte, or the shown form (ops, `!`, `~`, `0` for a zero,
`·` or `_` for a no-op), padded with zeros to the run's assayed length.";

struct Args {
    positional: Vec<String>,
    flags: HashMap<String, String>,
}

impl Args {
    fn parse(raw: impl Iterator<Item = String>) -> Result<Self, String> {
        let mut positional = Vec::new();
        let mut flags = HashMap::new();
        let mut raw = raw.peekable();
        while let Some(arg) = raw.next() {
            match arg.strip_prefix("--") {
                Some(flag) => {
                    let value = raw.next().ok_or(format!("--{flag} needs a value"))?;
                    flags.insert(flag.to_string(), value);
                }
                None => positional.push(arg),
            }
        }
        Ok(Self { positional, flags })
    }

    fn get(&self, flag: &str) -> Result<&str, String> {
        self.flags
            .get(flag)
            .map(String::as_str)
            .ok_or(format!("--{flag} is required"))
    }

    fn number<T: std::str::FromStr>(&self, flag: &str, default: T) -> Result<T, String> {
        self.flags.get(flag).map_or(Ok(default), |value| {
            value
                .parse()
                .map_err(|_| format!("--{flag} {value:?} is not a number"))
        })
    }

    fn path(&self, flag: &str) -> Result<PathBuf, String> {
        self.get(flag).map(PathBuf::from)
    }

    fn arg(&self, at: usize, name: &str) -> Result<&str, String> {
        self.positional
            .get(at)
            .map(String::as_str)
            .ok_or(format!("{name} is required"))
    }
}

fn main() -> ExitCode {
    let mut raw = std::env::args().skip(1);
    let Some(command) = raw.next() else {
        eprintln!("{USAGE}");
        return ExitCode::FAILURE;
    };
    let result = Args::parse(raw).and_then(|args| match command.as_str() {
        "census" => census(&args),
        "distance" => distance(&args),
        "loadbearing" => loadbearing(&args),
        "mcshea" => mcshea(&args),
        "paths" => paths(&args),
        "plant" => plant(&args),
        "trace" => trace(&args),
        _ => Err(USAGE.into()),
    });
    match result {
        Ok(report) => {
            print!("{report}");
            ExitCode::SUCCESS
        }
        Err(message) => {
            eprintln!("{message}");
            ExitCode::FAILURE
        }
    }
}

fn census(args: &Args) -> Result<String, String> {
    let stored = Stored::load(&args.path("snapshot")?, &args.path("params")?)?;
    let world = stored.world(0)?;
    if let Some(scorer) = DepthScorer::for_params(&stored.params) {
        return Ok(depth_census::census(&world, &scorer).render());
    }
    let scorer = Scorer::for_params(&stored.params);
    Ok(census::census(&world, &scorer, args.number("top", 8)?).render())
}

fn depth_scorer(params: &life_engine::Params) -> Result<DepthScorer, String> {
    DepthScorer::for_params(params)
        .ok_or("this reads the topless ladder: the run's tasks are not logic3 or logic4".into())
}

/// McShea's minimum of one stored world, or of a child's fifth-decile and last worlds side
/// by side.
fn mcshea(args: &Args) -> Result<String, String> {
    let names: &[&str] = if args.flags.contains_key("snapshot") {
        &["snapshot"]
    } else {
        &["fifth", "last"]
    };
    let params = args.path("params")?;
    let mut minima = Vec::new();
    for name in names {
        let stored = Stored::load(&args.path(name)?, &params)?;
        let scorer = depth_scorer(&stored.params)?;
        minima.push(mcshea::minimum(&stored.world(0)?, &scorer));
    }
    let columns: Vec<(&str, &mcshea::Minimum)> = names
        .iter()
        .map(|name| if *name == "snapshot" { "world" } else { name })
        .zip(&minima)
        .collect();
    Ok(mcshea::render(&columns))
}

/// For a tape, its load-bearing bytes against `--depth`, its own depth by default. For a
/// stored world, those of its dominant deepest solver against the world's deepest solid
/// rung. For a child's worlds (`--fifth` and `--last`, and `--first` if given), each in turn
/// and the entry's label, judged from the fifth-decile world to the last.
fn loadbearing(args: &Args) -> Result<String, String> {
    let worlds = [
        ("first", "first settled world"),
        ("fifth", "fifth-decile world"),
        ("last", "last world"),
    ];
    if worlds
        .iter()
        .any(|(world, _)| args.flags.contains_key(*world))
    {
        let params = args.path("params")?;
        let mut out = String::new();
        let mut read = HashMap::new();
        for (world, title) in worlds {
            if world == "first" && !args.flags.contains_key(world) {
                continue;
            }
            let stored = Stored::load(&args.path(world)?, &params)?;
            let (reading, report) = world_bearing(&stored)?;
            out.push_str(&format!("{title}\n{report}\n"));
            read.insert(world, reading);
        }
        let label = rise_code(read["fifth"], read["last"]);
        out.push_str(&format!(
            "H-rise-code, fifth-decile world to last: {label}\n"
        ));
        return Ok(out);
    }
    if args.flags.contains_key("snapshot") {
        let stored = Stored::load(&args.path("snapshot")?, &args.path("params")?)?;
        return Ok(world_bearing(&stored)?.1);
    }
    let params = read_params(&args.path("params")?)?;
    let scorer = depth_scorer(&params)?;
    let tape = tape::parse(args.arg(0, "the tape")?, assayed_len(&params))?;
    let own = scorer
        .solid(&tape)
        .depth()
        .ok_or("the tape is credited no rung on all 6 sets")?;
    let depth = args.number("depth", own)?;
    if depth > own {
        return Err(format!(
            "the tape is credited depth {own} on all 6 sets, short of --depth {depth}"
        ));
    }
    Ok(load_bearing(&tape, &scorer, depth).render())
}

/// A stored world's deepest solid rung and its dominant solver's load-bearing count, if it
/// holds one, and its report.
fn world_bearing(stored: &Stored) -> Result<(Option<(u32, usize)>, String), String> {
    let scorer = depth_scorer(&stored.params)?;
    let census: DepthCensus = depth_census::census(&stored.world(0)?, &scorer);
    let Some(deepest) = &census.deepest else {
        return Ok((
            None,
            format!("epoch {}: no rung held by a tenth\n", census.epoch),
        ));
    };
    let bearing = load_bearing(&deepest.solver, &scorer, deepest.depth);
    let report = format!(
        "epoch {}: deepest solid rung {}, dominant deepest solver on {} cells\n{}",
        census.epoch,
        depth_name(deepest.depth),
        deepest.solver_cells,
        bearing.render()
    );
    Ok((Some((deepest.depth, bearing.count())), report))
}

fn distance(args: &Args) -> Result<String, String> {
    let params = read_params(&args.path("params")?)?;
    let len = assayed_len(&params);
    let a = tape::parse(args.arg(0, "tape A")?, len)?;
    let b = tape::parse(args.arg(1, "tape B")?, len)?;
    Ok(paths::distance(&a, &b, &Scorer::for_params(&params)).render())
}

fn paths(args: &Args) -> Result<String, String> {
    let params = read_params(&args.path("params")?)?;
    let start = tape::parse(args.arg(0, "the start tape")?, assayed_len(&params))?;
    let k = args.number("k", 3)?;
    if !(1..=4).contains(&k) {
        return Err("--k is 1 to 4: the study searched exhaustively to 3".into());
    }
    let target = match args.flags.get("rungs") {
        Some(list) => Rungs::parse(list)?,
        None => DEEP,
    };
    let search = paths::search(
        &start,
        &Scorer::for_params(&params),
        args.number("window", start.len())?,
        k,
        target,
    );
    Ok(search.render(args.number("examples", 4)?))
}

fn plant(args: &Args) -> Result<String, String> {
    let stored = Stored::load(&args.path("snapshot")?, &args.path("params")?)?;
    let params = &stored.params;
    let len = assayed_len(params);
    let deep = tape::parse(args.get("deep")?, len)?;
    let replicating = if !params.carries_meta() {
        None
    } else if let Some(spelled) = args.flags.get("replicating") {
        Some(tape::parse(spelled, 0)?)
    } else {
        let source = match args.flags.get("source") {
            Some(path) => Stored {
                params: params.clone(),
                blob: std::fs::read(path).map_err(|e| format!("reading {path}: {e}"))?,
            },
            None => Stored {
                params: params.clone(),
                blob: stored.blob.clone(),
            },
        };
        Some(plant::replicating_of(&source.world(0)?, &deep).ok_or(
            "no cell holds the deep tape: name the world it was found in with --source, or its \
             replicating tape with --replicating",
        )?)
    };
    let seeds = match args.flags.get("seeds") {
        Some(list) => list
            .split(',')
            .map(|seed| seed.parse().map_err(|_| format!("{seed:?} is not a seed")))
            .collect::<Result<Vec<u64>, String>>()?,
        None => plant::SEEDS.to_vec(),
    };
    let plan = plant::Plan {
        rung: rung_index(args.get("rung")?)?,
        deep,
        replicating,
        side: args.number("side", plant::SIDE)?,
        seeds,
        epochs: args.number("epochs", plant::EPOCHS)?,
        every: args.number("every", 500)?.max(1),
    };
    let planting = plant::plant(&stored, &Scorer::for_params(params), &plan)?;
    Ok(planting.render(&plan))
}

fn trace(args: &Args) -> Result<String, String> {
    let params = read_params(&args.path("params")?)?;
    let tape = tape::parse(args.arg(0, "the tape")?, assayed_len(&params))?;
    let rung = rung_index(args.get("rung")?)?;
    let reading = trace::reading(&tape, &Scorer::for_params(&params), rung);
    Ok(reading.render(args.number("lines", 60)?))
}
