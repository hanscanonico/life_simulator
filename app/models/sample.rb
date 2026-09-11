# frozen_string_literal: true

class Sample < ApplicationRecord
  # The DESIGN.md §1.2 observables in the engine's `Metrics` field order — the fixed
  # column order of every export. Keep in sync with
  # engine/crates/life-engine/src/metrics.rs.
  OBSERVABLES = %w[
    compress_ratio distinct_tapes top_share op_density replicator_count entropy_bits alphabet_size copy_rate
  ].freeze

  belongs_to :run

  validates :epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                    uniqueness: { scope: :run_id }
end
