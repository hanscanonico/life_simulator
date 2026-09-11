# frozen_string_literal: true

# One reading of a stored world at one `top_k`, as `runner rescore-corpus` measured it.
# A rescore never changes the run it reads: `top_k` is locked at 16 for a run's own
# metrics (DESIGN §1.2), and these rows are what a proposal to move it is argued from.
class Rescore < ApplicationRecord
  READINGS = %w[replicator_count top_share distinct_tapes compress_ratio entropy_bits].freeze

  belongs_to :run

  validates :epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                    uniqueness: { scope: %i[run_id top_k] }
  validates :top_k, numericality: { only_integer: true, greater_than: 0 }
  validates :replicator_count, :distinct_tapes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
