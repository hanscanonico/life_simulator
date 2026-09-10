//! `runner` — executes simulation jobs. Local mode writes files, lab mode talks HTTP to
//! Rails; both share `run::execute_world` through the `RunSink` trait.

mod api;
mod file_sink;
mod http_sink;
mod lab;
#[cfg(test)]
mod mock_lab;
mod run;
mod sink;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use file_sink::FileSink;
use lab::Lab;
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
    /// Claim runs from the Rails lab API and execute them until stopped.
    Lab {
        /// Base URL of the app, e.g. `http://app:8080`.
        #[arg(long, env = "RUNNER_API")]
        api: String,
        /// The shared secret the API expects as a bearer token.
        #[arg(long, env = "RUNNER_TOKEN")]
        token: String,
        /// Runs executed at once; defaults to the cores the site does not keep.
        #[arg(long, env = "RUNNER_PARALLELISM")]
        parallelism: Option<usize>,
        /// Identifies this runner to the app; defaults to the host and pid.
        #[arg(long, env = "RUNNER_ID")]
        runner_id: Option<String>,
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
        Command::Lab {
            api,
            token,
            parallelism,
            runner_id,
        } => {
            let parallelism = parallelism.unwrap_or_else(lab::default_parallelism);
            let runner_id = runner_id.unwrap_or_else(default_runner_id);
            Lab::new(&api, &token, &runner_id, parallelism).work()?;
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

/// Distinct per host and per process, so two runners never claim as one another.
fn default_runner_id() -> String {
    let host = std::env::var("HOSTNAME").unwrap_or_else(|_| "runner".to_string());
    format!("{host}-{}", std::process::id())
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
