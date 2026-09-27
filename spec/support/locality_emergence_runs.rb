# frozen_string_literal: true

# Runs of the locality-emergence sweep, and arms counted without them, for the specs of its
# reading, its page section and its report.
module LocalityEmergenceRuns
  def locality_emergence_experiment
    create(:experiment, name: "Locality and emergence", slug: "locality-emergence",
                        **Lab::SWEEPS.fetch("locality_emergence").slice(:param_grid, :epochs))
  end

  # A run at `radius`. `share` samples from epoch 1 000 on, where the run crosses: a share
  # of at least one half makes it emerged, and nil leaves it without a crossing at all.
  def locality_run(experiment, radius:, share: nil, status: "finished", seed: nil)
    crossing = share.nil? ? nil : 1_000
    run = create(:run, experiment: experiment, status: status, emergence_epoch: crossing,
                       seed: seed || generate(:locality_seed),
                       params: Lab::Schema.run_defaults.merge("radius" => radius))
    create(:sample, run: run, epoch: 1_000, values: { "replicator_share" => share }) unless share.nil?
    run
  end

  # An arm of `finished` finished runs, `emerged` of them emerged.
  def locality_arm(radius, emerged, finished)
    rows = Array.new(finished) do |index|
      Experiments::LocalityEmergenceReadingService::RunRow.new(
        run_id: index, radius: radius, seed: index, status: "finished", emergence_epoch: nil,
        emerged: index < emerged
      )
    end
    Lab::LocalityEmergenceReading::Arm.new(radius: radius, rows: rows)
  end
end

FactoryBot.define { sequence(:locality_seed) { |n| n } }

RSpec.configure { |config| config.include LocalityEmergenceRuns }
