# frozen_string_literal: true

module Runs
  # What became of a run after it crossed the transition: how high its replicator census
  # rose and where, how many epochs the world held the transitioned state, and whether it
  # fell back out of it before its last sample (DESIGN.md §1.2 — a transition is a state a
  # world can leave). Derived from stored samples by PersistenceSummaryService and kept on
  # the run as `runs.persistence`.
  class Persistence < Data.define(:census_peak, :peak_epoch, :epochs_persisted, :relapsed)
    # Leaving the transitioned state takes this many consecutive rejecting samples, the
    # entry hold plus the sample that starts the run of them (docs/design_record.md,
    # 2026-09-12).
    EXIT_SAMPLES = Lab::TransitionRule::HOLD_SAMPLES + 1

    # Reads a summary whichever way it is keyed: the jsonb column hands back strings, and a
    # summary that has not been through the column yet still carries the service's symbols.
    def self.from(attributes)
      return nil if attributes.blank?

      values = attributes.symbolize_keys

      new(census_peak: values[:census_peak], peak_epoch: values[:peak_epoch],
          epochs_persisted: values[:epochs_persisted], relapsed: values[:relapsed])
    end

    def self.none = Missing.new

    # A series shorter than an exit takes, counted from the crossing onwards, has no room
    # for one to be confirmed in: such a run reads as persisted whatever the world did.
    def self.exit_confirmable?(sample_count_from_transition)
      sample_count_from_transition >= EXIT_SAMPLES
    end

    def summarised? = true

    def relapsed? = relapsed

    def persisted? = !relapsed

    # A census that never left zero has no peak: that is a reading, not a gap. A run whose
    # samples carry no `replicator_count` at all has neither, and is not counted?.
    def counted? = census_peak.to_f.positive?

    def sampled? = census_peak.present?

    # The census peak with what its absence means, since zero and never-taken are different
    # readings of the record.
    def census_label
      return "— (not sampled)" unless sampled?
      return "0 (no replicator counted)" unless counted?

      compact_census_label
    end

    # The same reading in a table cell, where the column heading already says what it is.
    def compact_census_label
      return "—" unless sampled?

      ActiveSupport::NumberHelper.number_to_delimited(census_peak.round)
    end
  end
end
