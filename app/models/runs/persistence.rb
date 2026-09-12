# frozen_string_literal: true

module Runs
  # What became of a run after it crossed the transition: how high its replicator census
  # rose and where, how many epochs the world held the transitioned state, and whether it
  # fell back out of it before its last sample (DESIGN.md §1.2 — a transition is a state a
  # world can leave). Derived from stored samples by PersistenceSummaryService and kept on
  # the run as `runs.persistence`.
  Persistence = Data.define(:census_peak, :peak_epoch, :epochs_persisted, :relapsed) do
    # Reads a summary whichever way it is keyed: the jsonb column hands back strings, and a
    # summary that has not been through the column yet still carries the service's symbols.
    def self.from(attributes)
      return nil if attributes.blank?

      values = attributes.symbolize_keys

      new(census_peak: values[:census_peak], peak_epoch: values[:peak_epoch],
          epochs_persisted: values[:epochs_persisted], relapsed: values[:relapsed])
    end

    def relapsed? = relapsed

    # A census that never left zero has no peak: that is a reading, not a gap. A run whose
    # samples carry no `replicator_count` at all has neither, and is not counted?.
    def counted? = census_peak.to_f.positive?

    def sampled? = census_peak.present?
  end
end
