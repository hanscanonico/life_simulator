# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Development-only fake data so the experiment, run and lab pages have something to draw
# locally. None of this is a measurement: the transition epochs come from a seeded RNG,
# not from the engine, which is why it never runs outside development.
if Rails.env.development?
  radii = [1, 2, 4, 64]
  sample_every = 500
  epochs = 20_000

  experiment = Experiment.find_or_initialize_by(slug: "demo-radius")
  experiment.update!(
    name: "Neighbourhood radius (demo data)",
    description: "Fabricated stand-in for DESIGN 1.3 sweep 3 until the lab has run it for real.",
    substrate: "soup", epochs: epochs, status: "running",
    param_grid: { "radius" => radii, "width" => [128], "height" => [128] }, seeds: (1..5).to_a
  )
  experiment.runs.destroy_all

  random = Random.new(20_260_910)

  radii.each do |radius|
    (1..5).each do |seed|
      # Locality is supposed to speed emergence, so the fake data leans that way; the
      # well-mixed arm mostly never transitions.
      centre = 2_500 * Math.log2(radius + 1) + random.rand(1_500)
      transition = radius == 64 && seed > 2 ? nil : (centre / sample_every).round * sample_every

      run = experiment.runs.create!(
        params: Lab::ENGINE_DEFAULTS.merge("radius" => radius, "width" => 128, "height" => 128),
        seed: seed, epochs: epochs, epochs_done: epochs, status: "finished",
        transition_epoch: transition, started_at: 2.days.ago, finished_at: 1.day.ago,
        heartbeat_at: 1.day.ago, runner_id: "demo-runner-#{(seed % 2) + 1}"
      )

      midpoint = transition || (epochs * 1.4)
      rows = (0..epochs).step(sample_every).map do |epoch|
        progress = 1 / (1 + Math.exp(-(epoch - midpoint) / 1_200.0))
        { run_id: run.id, epoch: epoch, created_at: Time.current, updated_at: Time.current,
          values: {
            "compress_ratio" => (1.0 - (0.62 * progress)).round(4),
            "distinct_tapes" => (16_384 * (1 - (0.85 * progress))).round,
            "top_share" => (0.0001 + (0.45 * progress)).round(4),
            "replicator_count" => (12_000 * progress).round,
            "op_density" => (0.039 + (0.11 * progress)).round(4),
            "entropy_bits" => (8.0 - (3.1 * progress)).round(3)
          } }
      end
      Sample.insert_all!(rows)
    end
  end

  puts "Seeded #{experiment.name}: #{experiment.reload.runs_count} runs, #{Sample.count} samples"
end
