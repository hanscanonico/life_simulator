# frozen_string_literal: true

# Runs of the lineage-diversity sweep and the samples they read, for the specs of its
# reading, its page section and its report.
module LineageDiversityRuns
  def lineage_diversity_experiment
    create(:experiment, name: "Lineage diversity", slug: "lineage-diversity",
                        **Lab::SWEEPS.fetch("lineage_diversity").slice(:param_grid, :epochs))
  end

  # A finished run at `radius` that emerged at epoch 1 000, with 100 samples from there on
  # whose `lineage_effective_count` reads `effective` throughout; nil samples nothing.
  def lineage_run(experiment, radius:, effective: nil, status: "finished", share: 0.9, seed: nil, extra: {})
    run = create(:run, :emerged, experiment: experiment, status: status, emergence_epoch: 1_000,
                                 transition_epoch: 1_000, seed: seed || generate(:lineage_seed),
                                 params: Lab::Schema.run_defaults.merge("radius" => radius))
    sample_lineages(run, effective, share: share, extra: extra) unless effective.nil?
    run
  end

  def sample_lineages(run, effective, share: 0.9, extra: {})
    now = Time.current
    Sample.insert_all(Array.new(100) do |index|
      { run_id: run.id, epoch: run.emergence_epoch + (10 * index), created_at: now, updated_at: now,
        values: { "replicator_share" => share, "lineage_effective_count" => effective,
                  "lineages_over_one_percent" => 2, **extra } }
    end)
  end
end

FactoryBot.define { sequence(:lineage_seed) { |n| n } }

RSpec.configure { |config| config.include LineageDiversityRuns }
