# frozen_string_literal: true

class Sample < ApplicationRecord
  # The DESIGN.md §1.2 observables in the engine's `Metrics` field order — the fixed
  # column order of every export. Keep in sync with
  # engine/crates/life-engine/src/metrics.rs.
  OBSERVABLES = %w[
    compress_ratio distinct_tapes top_share op_density replicator_count entropy_bits alphabet_size copy_rate
    distinct_lineages top_lineage_share lineage_variation copy_cost dominant_compressed_len
    dominant_instruction_count dominant_replicates dominant_raw_len dominant_tape_hash
    conserved_core_bytes conserved_core_ops
  ].freeze

  # The observables that are not numbers: exported like the rest, but there is no series a
  # chart could draw of them. The tape hash is one of them — sixteen hex digits that are
  # only ever compared for equality (DESIGN §1.2).
  FLAGS = %w[dominant_replicates dominant_tape_hash].freeze
  PLOTTABLE = (OBSERVABLES - FLAGS).freeze

  belongs_to :run

  validates :epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                    uniqueness: { scope: :run_id }
end
