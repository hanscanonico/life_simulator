# frozen_string_literal: true

module Runs
  # A run's confirmed crossing: the epoch the detector flagged, once the census or the copy
  # rate backs it (docs/design_record.md, 2026-09-15), and which of the two backed it.
  # Derived from stored samples by EmergenceEpochService and kept on the run as
  # `runs.emergence_epoch` / `runs.emergence_witness`.
  class Emergence < Data.define(:epoch, :witness)
    CENSUS = "census"
    COPY_RATE = "copy_rate"

    def self.none = new(epoch: nil, witness: nil)

    def confirmed? = epoch.present?

    def attributes = { emergence_epoch: epoch, emergence_witness: witness }
  end
end
