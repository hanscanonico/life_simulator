# frozen_string_literal: true

module Experiments
  # One arm of a sweep — every finished run at a single grid value — read as the share of
  # runs in which a self-replicator emerged and the spread of the epochs at which it did.
  #
  # Censored runs (no emergence within the run's epoch budget) count towards `n` but never
  # towards the percentiles: they have a lower bound, not an epoch.
  ArmSummary = Data.define(:label, :transition_epochs, :censored) do
    def runs_finished = transitioned + censored

    def transitioned = transition_epochs.size

    def transition_fraction
      return nil if runs_finished.zero?

      transitioned.fdiv(runs_finished)
    end

    def median_epoch = percentile(0.5)

    def q1_epoch = percentile(0.25)

    def q3_epoch = percentile(0.75)

    private

    def percentile(fraction)
      return nil if transition_epochs.empty?

      sorted = transition_epochs.sort
      position = fraction * (sorted.size - 1)
      lower = sorted[position.floor]
      upper = sorted[position.ceil]

      lower.to_f + ((upper - lower) * (position - position.floor))
    end
  end
end
