# frozen_string_literal: true

# A descendant is read over its own samples, and a decile holds the ten a child is measured
# on only from a hundred samples up: a sweep's worth of children goes in per statement
# rather than paying the factory per row.
module OwnSamples
  # One sample per element of `values`, `every` epochs apart from just past the run's
  # parent epoch.
  def insert_own_samples(run, values, every: 10)
    now = Time.current
    Sample.insert_all(values.each_with_index.map do |sample, index|
      { run_id: run.id, epoch: run.parent_epoch + (every * (index + 1)), values: sample,
        created_at: now, updated_at: now }
    end)
  end
end

RSpec.configure { |config| config.include OwnSamples }
