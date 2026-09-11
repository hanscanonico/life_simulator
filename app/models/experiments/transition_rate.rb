# frozen_string_literal: true

module Experiments
  # How often the transition detector flagged a finished run, over the runs that had the
  # chance to show one.
  #
  # Only finished runs are in the denominator: a pending run is not evidence either way,
  # and counting it would drag every young sweep's rate towards zero.
  TransitionRate = Data.define(:transitioned, :finished) do
    def fraction
      return nil if finished.zero?

      transitioned.fdiv(finished)
    end
  end
end
