# frozen_string_literal: true

# A report read over a whole sweep is read over hundreds of runs carrying hundreds of
# samples each, and the spec that bounds what such a read holds at once never looks at a
# single row: the corpus goes in per statement instead of paying the factory per row.
module SweepRows
  def insert_sweep(experiment, runs:, samples_per_run:, params: {}, &)
    now = Time.current
    run_ids = Run.insert_all(sweep_runs(experiment, runs, params, now)).rows.flatten
    values = Array.new(samples_per_run, &)

    run_ids.each_slice(50) do |ids|
      Sample.insert_all(ids.flat_map { |run_id| sweep_samples(run_id, values, now) })
    end

    run_ids
  end

  private

  def sweep_runs(experiment, runs, params, now)
    Array.new(runs) do |index|
      { experiment_id: experiment.id, seed: 10_000 + index, epochs: 100_000, status: "finished",
        transition_epoch: 10_000, params: Lab::Schema.run_defaults.merge(params),
        created_at: now, updated_at: now }
    end
  end

  def sweep_samples(run_id, values, now)
    values.each_with_index.map do |sample, index|
      { run_id: run_id, epoch: (index + 1) * 100, values: sample, created_at: now, updated_at: now }
    end
  end
end

RSpec.configure { |config| config.include SweepRows }
