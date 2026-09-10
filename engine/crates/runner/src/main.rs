//! `runner` — executes simulation jobs. Local mode writes files; lab mode (HTTP to
//! Rails) is a later task and shares `run::execute` through the `RunSink` trait.

mod file_sink;
mod run;
mod sink;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use file_sink::FileSink;
use life_engine::Params;
use sink::NullSink;
use std::io::Read;
use std::path::PathBuf;

const BENCH_EPOCHS: u64 = 20;

#[derive(Parser)]
#[command(name = "runner", about = "Executes Life Simulator runs")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Print the parameter schema Rails builds its forms and validations from.
    Schema,
    /// Execute a run, writing samples, snapshots and a result summary.
    Run {
        /// Params JSON file, or `-` for stdin.
        #[arg(long)]
        params: String,
        #[arg(long, default_value_t = 0)]
        seed: u64,
        #[arg(long)]
        epochs: u64,
        #[arg(long)]
        out: PathBuf,
    },
    /// Report epochs per second for a short run.
    Bench {
        #[arg(long)]
        params: String,
        #[arg(long, default_value_t = 0)]
        seed: u64,
        #[arg(long, default_value_t = BENCH_EPOCHS)]
        epochs: u64,
    },
}

fn main() -> Result<()> {
    match Cli::parse().command {
        Command::Schema => println!("{}", Params::schema_json()),
        Command::Run {
            params,
            seed,
            epochs,
            out,
        } => {
            let params = read_params(&params)?;
            let mut sink = FileSink::create(&out)?;
            let result = run::execute(&params, seed, epochs, &mut sink)?;
            println!(
                "{} epochs in {:.1}s ({:.2} epochs/s), transition_epoch {}",
                result.epochs,
                result.wall_seconds,
                result.epochs_per_second,
                result
                    .transition_epoch
                    .map_or_else(|| "none".to_string(), |e| e.to_string())
            );
        }
        Command::Bench {
            params,
            seed,
            epochs,
        } => {
            let params = read_params(&params)?;
            let result = run::execute(&params, seed, epochs, &mut NullSink)?;
            println!(
                "{}×{} {:?}: {:.2} epochs/s ({} epochs in {:.1}s)",
                params.width,
                params.height,
                params.substrate,
                result.epochs_per_second,
                result.epochs,
                result.wall_seconds
            );
        }
    }
    Ok(())
}

fn read_params(source: &str) -> Result<Params> {
    let json = if source == "-" {
        let mut buffer = String::new();
        std::io::stdin().read_to_string(&mut buffer)?;
        buffer
    } else {
        std::fs::read_to_string(source).with_context(|| format!("reading {source}"))?
    };
    let params: Params =
        serde_json::from_str(&json).with_context(|| format!("parsing {source}"))?;
    params.validate().map_err(anyhow::Error::msg)?;
    Ok(params)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Rails reads the schema from `config/engine_schema.json`, a copy of this command's
    /// output; `make schema` refreshes it and this test is what stops it drifting.
    #[test]
    fn the_schema_rails_reads_is_the_engines_own() {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../config/engine_schema.json");
        let committed = std::fs::read_to_string(&path).expect("the committed schema exists");
        assert_eq!(
            committed.trim_end(),
            Params::schema_json().trim_end(),
            "config/engine_schema.json is stale — run `make schema`"
        );
    }
}
