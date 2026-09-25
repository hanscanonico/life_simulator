# frozen_string_literal: true

module Runs
  # Every qualifying crossing a run's stored samples hold, in epoch order: the first sample
  # `Lab::TransitionRule` accepts of a stretch it keeps accepting for `HOLD_SAMPLES` more,
  # entered from a stretch it rejects. The engine's tracker keeps only the first of them
  # (`transition_epoch`, DESIGN.md §1.2), so this is the one place that reads the rest —
  # a world can leave the transitioned state and enter it again, and the crossing that
  # carries a witness need not be the one the detector stored (docs/design_record.md,
  # 2026-09-15).
  #
  # `samples` is [epoch, values] in epoch order; it reads them and changes nothing. Given
  # a `baseline` it runs the transition rule, and without one the constant companion of
  # `docs/design_record.md`, 2026-09-21 — which is what the crossing *series* is read by:
  # the relative rule cannot judge a crossing inside its own baseline window, and a second
  # crossing would be judged against a baseline the first one contaminated.
  class CrossingsService
    include Callable

    HOLD_SAMPLES = Lab::TransitionRule::HOLD_SAMPLES

    def initialize(samples:, baseline: nil)
      @samples = samples
      @baseline = baseline
    end

    def call
      crossings = []
      candidate = nil
      held = 0

      @samples.each do |epoch, values|
        unless qualifies?(values)
          candidate = nil
          held = 0
          next
        end

        if candidate.nil?
          candidate = epoch
          held = 0
        else
          held += 1
          crossings << candidate if held == HOLD_SAMPLES
        end
      end

      crossings
    end

    private

    def qualifies?(values)
      return Lab::TransitionRule.qualifies_constant?(values) if @baseline.nil?

      Lab::TransitionRule.qualifies_relative?(values, baseline: @baseline)
    end
  end
end
