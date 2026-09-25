# frozen_string_literal: true

module Runs
  # The transition read against the constant threshold the observable was defined by
  # before the 2026-09-21 relock, off a run's stored samples: the companion reading beside
  # `TransitionEpochService`, kept so every finding stated on the constant rule can still
  # be read and so a cap-confounded flag can still be told from the rule that now settles
  # the run's `transition_epoch`.
  class ConstantTransitionEpochService
    include Callable

    def initialize(run: nil, samples: nil)
      @run = run
      @samples = samples
    end

    def call = CrossingsService.call(samples: samples).first

    private

    def samples = @samples ||= @run ? @run.samples.order(:epoch).pluck(:epoch, :values) : []
  end
end
