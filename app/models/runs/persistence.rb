# frozen_string_literal: true

module Runs
  # What became of a run after it crossed the transition: how high its replicator census
  # rose and where, how many epochs the world held the transitioned state, and whether it
  # fell back out of it before its last sample (DESIGN.md §1.2 — a transition is a state a
  # world can leave). Derived from stored samples by PersistenceSummaryService and kept on
  # the run as `runs.persistence`.
  Persistence = Data.define(:census_peak, :peak_epoch, :epochs_persisted, :relapsed) do
    def self.from(attributes)
      return nil if attributes.blank?

      new(census_peak: attributes["census_peak"], peak_epoch: attributes["peak_epoch"],
          epochs_persisted: attributes["epochs_persisted"], relapsed: attributes["relapsed"])
    end

    def relapsed? = relapsed

    # A census that never left zero has no peak: that is a reading, not a gap.
    def counted? = census_peak.to_f.positive?
  end
end
