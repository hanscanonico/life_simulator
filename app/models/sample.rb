# frozen_string_literal: true

class Sample < ApplicationRecord
  # The DESIGN.md §1.2 observables in the engine's `Metrics` field order — the fixed
  # column order of every export. Keep in sync with
  # engine/crates/life-engine/src/metrics.rs.
  OBSERVABLES = %w[
    compress_ratio distinct_tapes top_share op_density replicator_count entropy_bits alphabet_size copy_rate
    distinct_lineages top_lineage_share lineage_variation copy_cost dominant_compressed_len
    dominant_instruction_count dominant_replicates dominant_raw_len dominant_tape_hash
    conserved_core_bytes conserved_core_ops steal_rate replicator_pass_rate replicator_count_mean
    lineage_compressed_len lineage_instruction_count reverse_copy_rate replicator_share replicator_share_rotated
    dominant_self_replicates lineage_variation_oriented conserved_core_bytes_oriented conserved_core_ops_oriented
    copy_latency copy_latency_orientation lineage_effective_count lineages_over_one_percent
  ].freeze

  # The observables that are not numbers: exported like the rest, but there is no series a
  # chart could draw of them. The tape hash is one of them — sixteen hex digits that are
  # only ever compared for equality (DESIGN §1.2). So is the latency's orientation: one of
  # three words.
  FLAGS = %w[dominant_replicates dominant_tape_hash dominant_self_replicates copy_latency_orientation].freeze
  PLOTTABLE = (OBSERVABLES - FLAGS).freeze

  belongs_to :run

  validates :epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                    uniqueness: { scope: :run_id }
end
