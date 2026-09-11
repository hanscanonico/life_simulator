//! Criterion benches for the hot loops of the engine: the BFF interpreter, one soup
//! epoch, one metrics sample — alone and taken with the snapshot of the same epoch —
//! and one Life epoch. Every input comes from a fixed seed, so two runs on the same
//! machine measure the same work.
//!
//! Baselines, criterion medians on an Apple M1 (two runs agreeing within 10%). They
//! move with the parameter defaults — `max_steps` above all — so a machine-to-machine
//! comparison of the absolute numbers means little; criterion's own report against the
//! previous local run is the regression signal.
//!
//! | bench                                  | median |
//! |----------------------------------------|--------|
//! | bff/random_128                         | 71 ns  |
//! | bff/handwritten_replicator_512         | 4.9 µs |
//! | world_step_soup/64x64                  | 3.6 ms |
//! | world_step_soup/128x128                | 13 ms  |
//! | world_metrics_soup/64x64               | 5.0 ms |
//! | world_metrics_soup/64x64_with_snapshot | 5.0 ms |
//! | world_step_life/512x512                | 746 µs |

use criterion::{criterion_group, criterion_main, BatchSize, Criterion};
use life_engine::params::{Init, Params, Substrate};
use life_engine::{bff, replicator, rng, World};

const MAX_STEPS: u32 = 8192;
const SEED: u64 = 42;

fn random_bytes(seed: u64, len: usize) -> Vec<u8> {
    let mut rng = rng::seeded(seed, 0, 0);
    (0..len).map(|_| rng::byte(&mut rng)).collect()
}

fn soup_world(side: u32) -> World {
    let params = Params {
        width: side,
        height: side,
        sample_every: 1,
        ..Params::default()
    };
    World::new(&params, SEED).expect("valid soup params")
}

fn life_world() -> World {
    let params = Params {
        substrate: Substrate::Life,
        width: 512,
        height: 512,
        mutation_rate: 0.0,
        init: Init::Random,
        ..Params::default()
    };
    World::new(&params, SEED).expect("valid life params")
}

fn bff_run(c: &mut Criterion) {
    let mut group = c.benchmark_group("bff");

    let random_pair = random_bytes(1, 128);
    group.bench_function("random_128", |b| {
        b.iter_batched_ref(
            || random_pair.clone(),
            |tape| bff::run(tape, MAX_STEPS),
            BatchSize::SmallInput,
        )
    });

    let mut replicator_pair = replicator::handwritten_replicator();
    replicator_pair.extend(random_bytes(2, replicator_pair.len()));
    group.bench_function("handwritten_replicator_512", |b| {
        b.iter_batched_ref(
            || replicator_pair.clone(),
            |tape| bff::run(tape, MAX_STEPS),
            BatchSize::SmallInput,
        )
    });

    group.finish();
}

fn world_step_soup(c: &mut Criterion) {
    let small = soup_world(64);
    let large = soup_world(128);
    let mut group = c.benchmark_group("world_step_soup");
    group.sample_size(20);
    group.bench_function("64x64", |b| {
        b.iter_batched_ref(|| small.clone(), World::step, BatchSize::LargeInput)
    });
    group.bench_function("128x128", |b| {
        b.iter_batched_ref(|| large.clone(), World::step, BatchSize::LargeInput)
    });
    group.finish();
}

fn world_metrics_soup(c: &mut Criterion) {
    let world = soup_world(64);
    let mut group = c.benchmark_group("world_metrics_soup");
    group.sample_size(20);
    group.bench_function("64x64", |b| {
        b.iter_batched_ref(|| world.clone(), World::metrics, BatchSize::LargeInput)
    });
    group.bench_function("64x64_with_snapshot", |b| {
        b.iter_batched_ref(
            || world.clone(),
            World::metrics_with_snapshot,
            BatchSize::LargeInput,
        )
    });
    group.finish();
}

fn world_step_life(c: &mut Criterion) {
    let world = life_world();
    let mut group = c.benchmark_group("world_step_life");
    group.bench_function("512x512", |b| {
        b.iter_batched_ref(|| world.clone(), World::step, BatchSize::LargeInput)
    });
    group.finish();
}

criterion_group!(
    benches,
    bff_run,
    world_step_soup,
    world_metrics_soup,
    world_step_life
);
criterion_main!(benches);
