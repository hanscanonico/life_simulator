# frozen_string_literal: true

module Experiments
  # One arm of a sweep — every finished run at a single grid value — read as the share of
  # runs in which a self-replicator emerged and the spread of the epochs at which it did.
  #
  # The detector flags a candidate crossing on `compress_ratio` alone; a run emerged only
  # where the census or the copy rate backed it (docs/design_record.md, 2026-09-15), so the
  # percentiles read the confirmed epochs and a flagged-but-unconfirmed run is censored
  # like a run that was never flagged at all. The flagged count and median stay beside
  # them, never in their place.
  ArmSummary = Data.define(:label, :emergence_epochs, :flagged_only_epochs, :unflagged) do
    def runs_finished = flagged + unflagged

    def emerged = emergence_epochs.size

    def flagged = emerged + flagged_only_epochs.size

    def censored = runs_finished - emerged

    def emergence_rate = TransitionRate.new(transitioned: emerged, finished: runs_finished)

    def flagged_rate = TransitionRate.new(transitioned: flagged, finished: runs_finished)

    def median_epoch = percentile(emergence_epochs, 0.5)

    def q1_epoch = percentile(emergence_epochs, 0.25)

    def q3_epoch = percentile(emergence_epochs, 0.75)

    def flagged_median_epoch = percentile(emergence_epochs + flagged_only_epochs, 0.5)

    private

    def percentile(epochs, fraction)
      return nil if epochs.empty?

      sorted = epochs.sort
      position = fraction * (sorted.size - 1)
      lower = sorted[position.floor]
      upper = sorted[position.ceil]

      lower.to_f + ((upper - lower) * (position - position.floor))
    end
  end
end
