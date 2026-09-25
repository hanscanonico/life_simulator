# frozen_string_literal: true

module Runs
  # Reads a terminal run's stored samples the way the engine's `TransitionTracker` read
  # them live (`engine/crates/life-engine/src/metrics.rs`): the transition epoch is the
  # first crossing of `RELATIVE_FRACTION` of the run's own baseline that holds, where the
  # baseline is the mean `compress_ratio` of the samples inside the first `BASELINE_EPOCHS`
  # epochs (docs/design_record.md, 2026-09-21).
  #
  # Nothing is read until the baseline window has closed, exactly as the engine's tracker
  # reads it: a run with no sample inside the window has no baseline, and one that never
  # sampled past it has no sample to be measured against it.
  #
  # It exists for runs measured before the tracker read them this way, and for runs
  # measured before it survived a snapshot resume: those runs reported a later epoch, or
  # none, while their samples hold the real drop. Live runs are not its business — the
  # runner posts the value with the samples.
  class TransitionEpochService
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

      @baseline = Lab::TransitionRule.baseline_of(samples)
    end
  end
end
