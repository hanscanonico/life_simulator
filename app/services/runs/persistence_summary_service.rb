# frozen_string_literal: true

module Runs
  # What became of a transitioned run, read off its stored samples: the replicator census
  # peak and the epoch it stood at, how many epochs the world held the transitioned state,
  # and whether it left that state before its last sample.
  #
  # "In the transitioned state" is the engine's own rule, sample by sample
  # (Lab::TransitionRule). Leaving it is read with the tracker's hold in reverse: the state
  # ends at the first of `hold_samples + 1` consecutive samples the rule rejects, so a
  # single sample flickering back above the threshold is no more a relapse than a single
  # sample below it is a transition. A state that never ends persisted to the last sample.
  #
  # It reads stored samples and changes nothing — not the detector, not a metric, not a run.
  class PersistenceSummaryService
    include Callable

    EXIT_SAMPLES = Lab::TransitionRule::HOLD_SAMPLES + 1

    def initialize(run:)
      @run = run
    end

    def call
      return nil if @run.transition_epoch.nil? || transitioned_samples.empty?

      Persistence.new(census_peak: census_peak, peak_epoch: peak_epoch,
                      epochs_persisted: epochs_persisted, relapsed: exit_index.present?)
    end

    private

    def samples = @samples ||= @run.samples.order(:epoch).pluck(:epoch, :values)

    def transitioned_samples
      @transitioned_samples ||= samples.drop_while { |epoch, _| epoch < @run.transition_epoch }
    end

    def epochs_persisted = [persisted_through.to_i - @run.transition_epoch, 0].max

    # The last epoch the world was still in the transitioned state: the last sample the
    # rule accepts before the exit, or before the end of the series when there is none.
    def persisted_through
      held = exit_index ? transitioned_samples.take(exit_index) : transitioned_samples
      last = held.reverse.find { |_, values| Lab::TransitionRule.qualifies?(values) }

      (last || transitioned_samples.first).first
    end

    def exit_index
      return @exit_index if defined?(@exit_index)

      qualifying = transitioned_samples.map { |_, values| Lab::TransitionRule.qualifies?(values) }
      @exit_index = (0..(qualifying.size - EXIT_SAMPLES)).find { |index| qualifying[index, EXIT_SAMPLES].none? }
    end

    def census_peak = peak_sample&.last&.fetch("replicator_count")

    # A peak of zero happened nowhere in particular, so its epoch stays blank rather than
    # pointing at whichever sample came first.
    def peak_epoch
      peak_sample.first if census_peak.to_f.positive?
    end

    def peak_sample
      @peak_sample ||= samples.select { |_, values| values["replicator_count"].is_a?(Numeric) }
                              .max_by { |_, values| values["replicator_count"] }
    end
  end
end
