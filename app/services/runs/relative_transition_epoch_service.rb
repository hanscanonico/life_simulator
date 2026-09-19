# frozen_string_literal: true

module Runs
  # The transition read against the run's own start rather than the constant threshold,
  # off the run's stored samples: the baseline is the mean `compress_ratio` of the samples
  # inside the first `BASELINE_EPOCHS` epochs, and the epoch is the first crossing of
  # `RELATIVE_FRACTION` of it that holds. It is a companion reading — `transition_epoch`
  # stays the locked observable every finding is stated in (docs/design_record.md,
  # 2026-09-19).
  #
  # Nothing is read until the baseline window has closed, exactly as the engine's tracker
  # reads it: a run with no sample inside the window has no baseline, and one that never
  # sampled past it has no settled baseline to be measured against.
  class RelativeTransitionEpochService
    include Callable

    BASELINE_EPOCHS = Lab::TransitionRule::BASELINE_EPOCHS

    # `samples` is the run's stored samples as [epoch, values] in epoch order, passed in by
    # a caller that already read them for a whole experiment and read here otherwise.
    def initialize(run: nil, samples: nil)
      @run = run
      @samples = samples
    end

    def call
      return nil if baseline.nil? || samples.none? { |epoch, _| epoch > BASELINE_EPOCHS }

      CrossingsService.call(samples: samples, baseline: baseline).first
    end

    private

    def samples = @samples ||= @run ? @run.samples.order(:epoch).pluck(:epoch, :values) : []

    def baseline
      return @baseline if defined?(@baseline)

      ratios = samples.filter_map { |epoch, values| values["compress_ratio"] if epoch <= BASELINE_EPOCHS }
      @baseline = ratios.empty? ? nil : ratios.sum / ratios.size
    end
  end
end
