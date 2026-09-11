# frozen_string_literal: true

class Snapshot < ApplicationRecord
  # Bytea imposes no size of its own, so the ceiling on a runner's upload is this one.
  # It sits well above the largest raw world the programme runs (the bff-control positive
  # control's 512×256 torus of 64-byte tapes, 8 MiB, and the engine compresses before
  # posting), while Params would allow 1024×1024×1024 = 1 GiB — revisit this with any
  # change to a Params range or to the sweep grid, since engine Params is the single
  # authority on world size (DESIGN §3).
  MAX_BYTES = 64.megabytes
  # Why the run loop took it: the epoch cadence, the runner's wall-clock ceiling on
  # snapshot age, or the sample that settled the transition. Keep in step with
  # `SnapshotReason` in engine/crates/runner/src/sink.rs, which names them.
  REASONS = %w[cadence age transition].freeze
  DEFAULT_REASON = "cadence"

  enum :reason, REASONS.index_by(&:itself), validate: true

  belongs_to :run

  # A snapshot with no world bytes cannot restore a run, only illustrate it.
  scope :restorable, -> { where.not(blob: nil) }

  validates :epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                    uniqueness: { scope: :run_id }
  validate :payloads_within_cap

  private

  def payloads_within_cap
    %i[blob png].each do |attribute|
      value = self[attribute]
      next if value.nil? || value.bytesize <= MAX_BYTES

      errors.add(attribute, "is #{value.bytesize} bytes, over the #{MAX_BYTES} byte limit")
    end
  end
end
