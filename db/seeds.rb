# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Development-only fake data so the experiment, run, findings and lab pages have something
# to draw locally. None of this is a measurement: the transition epochs come from a seeded
# RNG, not from the engine, which is why it never runs outside development.
if Rails.env.development?
  sample_every = 500
  epochs = 20_000
  # A 128x128 soup burns epochs at roughly this rate on the mini-pc, and `Runs::ShowPage`
  # measures the rate it reports from the gap between the first and the last sample, so the
  # fake samples have to be spaced like real ones or the demo run reads megaepochs a second.
  epochs_per_second = 50

  # One run's metric series. `midpoint` is where the sigmoid sits and `scale` how many
  # epochs it takes to cross: a scale of one sampling interval is the cliff a transitioning
  # run shows, and no midpoint at all is a soup that never left the random-soup plateau.
  series = lambda do |run, midpoint:, scale: 1_200, last_epoch: epochs|
    recorded_at = run.finished_at || Time.current
    rows = (0..last_epoch).step(sample_every).map do |epoch|
      progress = midpoint.nil? ? 0.0 : 1 / (1 + Math.exp(-(epoch - midpoint) / scale.to_f))
      written_at = recorded_at - ((last_epoch - epoch) / epochs_per_second.to_f).seconds
      { run_id: run.id, epoch: epoch, created_at: written_at, updated_at: written_at,
        values: {
          "compress_ratio" => (1.0 - (0.62 * progress)).round(4),
          "distinct_tapes" => (16_384 * (1 - (0.85 * progress))).round,
          "top_share" => (0.0001 + (0.45 * progress)).round(4),
          "replicator_count" => (12_000 * progress).round,
          "op_density" => (0.039 + (0.11 * progress)).round(4),
          "entropy_bits" => (8.0 - (3.1 * progress)).round(3),
          "copy_rate" => (0.6 * progress).round(4)
        } }
    end
    # Runs::RecordSamplesService writes the newest sample onto the run as it ingests a
    # batch; inserting the rows behind its back has to hold that invariant, or every
    # summary-fed reading (the runs table's census, the CSV) reads blank in development.
    Sample.insert_all!(rows)
    run.update!(summary: rows.last[:values])
  end

  sweep = lambda do |slug, attributes|
    experiment = Experiment.find_or_initialize_by(slug: slug)
    experiment.update!(**attributes, substrate: "soup", epochs: epochs)
    experiment.runs.destroy_all
    experiment
  end

  finished = lambda do |experiment, params:, seed:, transition:|
    experiment.runs.create!(
      params: Lab::Schema.run_defaults.merge(params), seed: seed, epochs: epochs, epochs_done: epochs,
      status: "finished", transition_epoch: transition, started_at: 2.days.ago, finished_at: 1.day.ago,
      heartbeat_at: 1.day.ago, runner_id: "demo-runner-#{(seed % 2) + 1}"
    )
  end

  radii = [1, 2, 4, 0]
  radius_sweep = sweep.call(
    "demo-radius",
    name: "Neighbourhood radius (demo data)",
    description: "Fabricated stand-in for DESIGN 1.3 sweep 3 until the lab has run it for real.",
    status: "running", param_grid: { "radius" => radii, "width" => [128], "height" => [128] }, seeds: (1..5).to_a
  )

  random = Random.new(20_260_910)

  radii.each do |radius|
    (1..5).each do |seed|
      # Locality is supposed to speed emergence, so the fake data leans that way; radius
      # 0 is the well-mixed arm — the widest reach of all — and mostly never transitions.
      reach = radius.zero? ? radii.max * 2 : radius
      centre = 2_500 * Math.log2(reach + 1) + random.rand(1_500)
      transition = radius.zero? && seed > 2 ? nil : (centre / sample_every).round * sample_every

      run = finished.call(radius_sweep, params: { "radius" => radius, "width" => 128, "height" => 128 },
                                        seed: seed, transition: transition)
      series.call(run, midpoint: transition || (epochs * 1.4))
    end
  end

  # The sweep the mutation-rate finding reads: the two ends of DESIGN 1.3 sweep 1's grid,
  # the rate at which the lab saw emergence, and the zero-mutation control. Only the
  # 2^-13 arm's first seed transitions, which is the run that finding quotes inline.
  emergent = Lab::EMERGENT_MUTATION_RATE
  rates = [0.0, 2.0**-16, emergent, 2.0**-8]
  transition_epoch = 8_500
  mutation_sweep = sweep.call(
    Lab.slug_for("mutation_rate"),
    name: "Mutation rate (demo data)",
    description: "Fabricated stand-in for DESIGN 1.3 sweep 1 until the lab has run it for real.",
    status: "running",
    param_grid: { "mutation_rate" => rates, "width" => [128], "height" => [128] }, seeds: (1..4).to_a
  )

  rates.each do |rate|
    (1..3).each do |seed|
      transition = rate == emergent && seed == 1 ? transition_epoch : nil
      run = finished.call(mutation_sweep, params: { "mutation_rate" => rate, "width" => 128, "height" => 128 },
                                          seed: seed, transition: transition)
      # A cliff inside a couple of sampling intervals, so the detector's rule — below 0.6
      # and staying there for three samples — fires exactly at the transition epoch.
      series.call(run, midpoint: transition && (transition - (sample_every / 2)), scale: sample_every / 2)
    end
  end

  in_flight = mutation_sweep.runs.create!(
    params: Lab::Schema.run_defaults.merge("mutation_rate" => emergent, "width" => 128, "height" => 128),
    seed: 4, epochs: epochs, epochs_done: 7_500, status: "running",
    started_at: (7_500 / epochs_per_second).seconds.ago, claimed_at: (7_500 / epochs_per_second).seconds.ago,
    heartbeat_at: 20.seconds.ago, runner_id: "demo-runner-1"
  )
  series.call(in_flight, midpoint: nil, last_epoch: in_flight.epochs_done)

  [radius_sweep, mutation_sweep].each do |experiment|
    puts "Seeded #{experiment.name}: #{experiment.reload.runs_count} runs"
  end
  puts "#{Sample.count} samples"
end
