use landscape::score::{assayed_len, rung_index, Rungs, Scorer, DEEP};
use landscape::stored::{read_params, Stored};
use landscape::{census, paths, plant, tape, trace};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "\
landscape census   --snapshot WORLD.lsnp --params PARAMS.json [--top 8]
landscape distance A B --params PARAMS.json
landscape paths    START --params PARAMS.json [--k 3] [--window LEN] [--rungs xor,equ] [--examples 4]
landscape plant    --snapshot END.lsnp --params PARAMS.json --deep TAPE --rung xor|equ
                   [--source WORLD.lsnp | --replicating TAPE] [--seeds 2001,2002,2003]
                   [--epochs 2000] [--every 500] [--side 4]
landscape trace    TAPE --params PARAMS.json --rung xor|equ [--lines 60]

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
    let scorer = Scorer::for_params(&stored.params);
    Ok(census::census(&world, &scorer, args.number("top", 8)?).render())
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
