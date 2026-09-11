//! `runner` — executes simulation jobs. Local mode writes files, lab mode talks HTTP to
//! Rails; both share `run::execute_world` through the `RunSink` trait.

mod api;
mod file_sink;
mod http_sink;
mod lab;
#[cfg(test)]
mod mock_lab;
mod rescore;
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
use std::time::Duration;

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
        /// Hold claims back while the process holds more than this — `5g`, `512m` or a
        /// byte count. Left out, nothing is held back.
        #[arg(long, env = "RUNNER_MAX_MEMORY", value_parser = lab::parse_memory_size)]
        max_memory: Option<u64>,
        /// A snapshot this old makes the next sampled epoch snapshot, whatever
        /// `snapshot_every` says — `10m`, `90s` or a second count.
        #[arg(long, env = "RUNNER_SNAPSHOT_MAX_AGE", value_parser = run::parse_duration)]
        snapshot_max_age: Option<Duration>,
        /// How long a run waits an unreachable app out before it is failed — `15m`,
        /// `900s` or a second count. A deploy recreates the app container for a minute
        /// or two, and the run's world is in memory throughout.
        #[arg(long, env = "RUNNER_OUTAGE_GRACE", value_parser = run::parse_duration)]
        outage_grace: Option<Duration>,
        /// Dry run: one worker, one claim, then exit — nothing is left claiming.
        #[arg(long)]
        once: bool,
    },
    /// Re-read a stored world at several `top_k` settings, without running anything.
    Rescore {
        /// Base URL of the app, e.g. `http://app:8080`.
        #[arg(long, env = "RUNNER_API")]
        api: Option<String>,
        /// The shared secret the API expects as a bearer token.
        #[arg(long, env = "RUNNER_TOKEN")]
        token: Option<String>,
        /// The run whose stored world to read.
        #[arg(long, conflicts_with = "file")]
        run: Option<i64>,
        /// Which snapshot of the run; the newest one when left out.
        #[arg(long, conflicts_with = "latest")]
        epoch: Option<u64>,
        /// Read the newest snapshot of the run — what happens anyway without `--epoch`.
        #[arg(long)]
        latest: bool,
        /// A snapshot blob on disk instead of the lab API; needs `--params`.
        #[arg(long, requires = "params")]
        file: Option<PathBuf>,
        /// Params JSON file describing `--file`, or `-` for stdin.
        #[arg(long)]
        params: Option<String>,
        /// The seed `--file` was run with; the replicator test draws from it.
        #[arg(long, default_value_t = 0)]
        seed: u64,
        /// The `top_k` settings to score the world at, comma separated.
        #[arg(long, value_delimiter = ',', default_value = "16,64,256")]
        top_k: Vec<u32>,
        /// Print the report as JSON instead of a table.
        #[arg(long)]
        json: bool,
    },
    /// Re-read every stored world of an experiment at several `top_k` settings and store
    /// the readings as rescore rows.
    RescoreCorpus {
        /// Base URL of the app, e.g. `http://app:8080`.
        #[arg(long, env = "RUNNER_API")]
        api: String,
        /// The shared secret the API expects as a bearer token.
        #[arg(long, env = "RUNNER_TOKEN")]
        token: String,
        /// The experiment whose finished runs to re-read, by slug.
        #[arg(long)]
        experiment: String,
        /// The `top_k` settings to score each world at, comma separated.
        #[arg(long, value_delimiter = ',', default_value = "16,64,256")]
        top_k: Vec<u32>,
        /// Which stored worlds of each run to read.
        #[arg(long, value_enum, default_value_t = rescore::Epochs::Latest)]
        epochs: rescore::Epochs,
        /// Stop after this many worlds.
        #[arg(long)]
        limit: Option<usize>,
        /// Measure and print, store nothing.
        #[arg(long)]
        dry_run: bool,
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
            max_memory,
            snapshot_max_age,
            outage_grace,
            once,
        } => {
            let parallelism = parallelism.unwrap_or_else(lab::default_parallelism);
            let runner_id = runner_id.unwrap_or_else(default_runner_id);
            let lab = Lab::new(
                &api,
                &token,
                &runner_id,
                parallelism,
                max_memory,
                snapshot_max_age.unwrap_or(run::SNAPSHOT_MAX_AGE),
                outage_grace.unwrap_or(api::OUTAGE_GRACE),
            );
            if once { lab.once() } else { lab }.work()?;
        }
        Command::Rescore {
            api,
            token,
            run,
            epoch,
            latest,
            file,
            params,
            seed,
            top_k,
            json,
        } => {
            let epoch = if latest { None } else { epoch };
            let source = match (run, file) {
                (Some(run), None) => rescore::Source::Lab {
                    api: api.context("rescoring a run needs --api")?,
                    token: token.context("rescoring a run needs --token")?,
                    run,
                    epoch,
                },
                (None, Some(path)) => rescore::Source::File {
                    path,
                    params: read_params(&params.context("--file needs --params")?)?,
                    seed,
                },
                _ => anyhow::bail!("rescore reads either --run <id> or --file <path>"),
            };
            let report = rescore::execute(rescore::Options { source, top_k })?;
            if json {
                println!("{}", serde_json::to_string_pretty(&report)?);
            } else {
                report.print();
            }
        }
        Command::RescoreCorpus {
            api,
            token,
            experiment,
            top_k,
            epochs,
            limit,
            dry_run,
        } => {
            rescore::execute_corpus(rescore::CorpusOptions {
                api,
                token,
                experiment,
                top_k,
                epochs,
                limit,
                dry_run,
            })?;
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
