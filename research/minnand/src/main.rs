use minnand::sat;
use minnand::table::{self, Proof, Table, AT_LEAST};
use std::collections::HashMap;
use std::process::ExitCode;
use std::time::Instant;

const USAGE: &str = "usage:
  minnand enumerate --inputs N --gates G [--threads T] [--out DIR]
  minnand close --inputs N --limit L [--deadline SECONDS] [--threads T] [--data DIR]
  minnand check --inputs N [--data DIR] [--study FILE --upto G]
  minnand synth --inputs N --tt HEX --gates K";

struct Args(HashMap<String, String>);

impl Args {
    fn parse(mut raw: impl Iterator<Item = String>) -> Result<Args, String> {
        let mut map = HashMap::new();
        while let Some(key) = raw.next() {
            let key = key
                .strip_prefix("--")
                .ok_or(format!("unexpected {key:?}"))?;
            let value = raw.next().ok_or(format!("--{key} needs a value"))?;
            map.insert(key.to_string(), value);
        }
        Ok(Args(map))
    }

    fn number(&self, key: &str, default: Option<usize>) -> Result<usize, String> {
        match self.0.get(key) {
            Some(v) => v.parse().map_err(|_| format!("--{key}: not a number")),
            None => default.ok_or(format!("--{key} is required")),
        }
    }

    fn text(&self, key: &str, default: &str) -> String {
        self.0
            .get(key)
            .cloned()
            .unwrap_or_else(|| default.to_string())
    }
}

fn main() -> ExitCode {
    let mut raw = std::env::args().skip(1);
    let Some(command) = raw.next() else {
        eprintln!("{USAGE}");
        return ExitCode::FAILURE;
    };
    let result = Args::parse(raw).and_then(|args| match command.as_str() {
        "enumerate" => enumerate(&args),
        "close" => close(&args),
        "check" => check(&args),
        "synth" => synth(&args),
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

fn paths(dir: &str, inputs: usize) -> [String; 3] {
    [
        format!("{dir}/minnand{inputs}.bin"),
        format!("{dir}/witnesses{inputs}.txt"),
        format!("{dir}/proofs{inputs}.txt"),
    ]
}

fn threads(args: &Args) -> Result<usize, String> {
    args.number(
        "threads",
        Some(std::thread::available_parallelism().map_or(1, |n| n.get())),
    )
}

fn write(table: &Table, dir: &str) -> Result<(), String> {
    let [bin, txt, _] = paths(dir, table.inputs);
    std::fs::write(&bin, table.bytes()).map_err(|e| format!("{bin}: {e}"))?;
    std::fs::write(&txt, table.witness_text()).map_err(|e| format!("{txt}: {e}"))
}

fn load(inputs: usize, dir: &str) -> Result<Table, String> {
    let [bin, txt, _] = paths(dir, inputs);
    let bytes = std::fs::read(&bin).map_err(|e| format!("{bin}: {e}"))?;
    let text = std::fs::read_to_string(&txt).map_err(|e| format!("{txt}: {e}"))?;
    Table::parse(inputs, &bytes, &text)
}

fn enumerate(args: &Args) -> Result<String, String> {
    let inputs = args.number("inputs", None)?;
    let gates = args.number("gates", None)?;
    let dir = args.text("out", "data");
    let start = Instant::now();
    let table = Table::enumerate(inputs, gates, threads(args)?);
    table.check_witnesses()?;
    write(&table, &dir)?;
    let [_, _, log] = paths(&dir, inputs);
    std::fs::write(&log, format!("{}{gates}\n", table::PROOF_HEADER))
        .map_err(|e| format!("{log}: {e}"))?;
    Ok(format!(
        "{}enumerated in {:.1}s wall\n",
        report(&table),
        start.elapsed().as_secs_f64()
    ))
}

fn close(args: &Args) -> Result<String, String> {
    let inputs = args.number("inputs", None)?;
    let limit = args.number("limit", None)?;
    let dir = args.text("data", "data");
    let mut table = load(inputs, &dir)?;
    let [_, _, log] = paths(&dir, inputs);
    let text = std::fs::read_to_string(&log).map_err(|e| format!("{log}: {e}"))?;
    let proofs = table::parse_proofs(inputs, &text)?;
    for proof in &proofs.lines {
        table.apply(proof)?;
    }
    let mut file = std::fs::OpenOptions::new()
        .append(true)
        .open(&log)
        .map_err(|e| format!("{log}: {e}"))?;
    let start = Instant::now();
    let deadline = match args.0.get("deadline") {
        Some(_) => {
            Some(start + std::time::Duration::from_secs(args.number("deadline", None)? as u64))
        }
        None => None,
    };
    let mut done = |p: &Proof| {
        use std::io::Write;
        writeln!(file, "{}", p.line()).expect("the proof log is writable");
        eprintln!("{}", p.line());
    };
    for proof in table.extend() {
        done(&proof);
        table.apply(&proof)?;
    }
    let left = table.close(limit, threads(args)?, deadline, &mut done)?;
    if left > 0 {
        eprintln!("deadline: {left} classes left unfinished");
    }
    table.check_witnesses()?;
    write(&table, &dir)?;
    Ok(format!(
        "{}closed in {:.1}s wall\n",
        report(&table),
        start.elapsed().as_secs_f64()
    ))
}

fn check(args: &Args) -> Result<String, String> {
    let inputs = args.number("inputs", None)?;
    let dir = args.text("data", "data");
    let table = load(inputs, &dir)?;
    table.check_witnesses()?;
    let [_, _, log] = paths(&dir, inputs);
    if let Ok(text) = std::fs::read_to_string(&log) {
        table::parse_proofs(inputs, &text)?.check(&table)?;
    }
    let mut out = report(&table);
    if let Some(study) = args.0.get("study") {
        let upto = args.number("upto", None)? as u8;
        let theirs = std::fs::read(study).map_err(|e| format!("{study}: {e}"))?;
        let mismatches = table
            .cost
            .iter()
            .zip(&theirs)
            .filter(|&(&ours, &their)| {
                if their <= upto {
                    ours != their
                } else {
                    ours <= upto
                }
            })
            .count();
        out += &format!("against {study} (exact to {upto}): {mismatches} mismatches\n");
    }
    Ok(out)
}

fn report(t: &Table) -> String {
    let mut out = format!(
        "{} inputs, {} classes with a witness\n",
        t.inputs,
        t.witness.len()
    );
    for (cost, n) in t.distribution() {
        let label = if cost & AT_LEAST != 0 {
            format!(">={}", cost & !AT_LEAST)
        } else {
            cost.to_string()
        };
        out += &format!("cost {label:>4}: {n:6}\n");
    }
    out += &format!("sha256 {}\n", table::sha256_hex(t.bytes()));
    out
}

fn synth(args: &Args) -> Result<String, String> {
    let inputs = args.number("inputs", None)?;
    let target = u16::from_str_radix(&args.text("tt", ""), 16).map_err(|e| format!("--tt: {e}"))?;
    let gates = args.number("gates", None)?;
    let start = Instant::now();
    let found = sat::synthesize(inputs, target, gates);
    let seconds = start.elapsed().as_secs_f64();
    Ok(match found {
        Some(c) => format!("SAT {} ({:.1}s)\n", c.encode(), seconds),
        None => format!("UNSAT ({seconds:.1}s)\n"),
    })
}
