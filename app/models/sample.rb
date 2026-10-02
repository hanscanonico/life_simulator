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
    task_share_echo task_share_inc task_share_dec task_share_add task_share_sub task_share_not task_share_double
    task_share_mul task_capability task_capability_loop dominant_tasks dominant_task_count
    logic_share_echo logic_share_not logic_share_nand logic_share_and logic_share_orn logic_share_or
    logic_share_andn logic_share_nor logic_share_xor logic_share_equ logic_capability logic_capability_deep
    dominant_logic_tasks dominant_logic_task_count meta_inherit_rate meta_diversity logic_capability_replicating
  ].freeze

  # The observables that are not numbers: exported like the rest, but there is no series a
  # chart could draw of them. The tape hash is one of them — sixteen hex digits that are
  # only ever compared for equality (DESIGN §1.2). So is the latency's orientation: one of
  # three words. `dominant_tasks` and `dominant_logic_tasks` are bitmasks of tasks, sets
  # rather than quantities.
  FLAGS = %w[
    dominant_replicates dominant_tape_hash dominant_self_replicates copy_latency_orientation dominant_tasks
    dominant_logic_tasks
  ].freeze
  PLOTTABLE = (OBSERVABLES - FLAGS).freeze

  belongs_to :run

  validates :epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                    uniqueness: { scope: :run_id }
end
