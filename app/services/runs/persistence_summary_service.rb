# frozen_string_literal: true

module Runs
  # What became of a transitioned run, read off its stored samples: the replicator census
  # peak and the epoch it stood at, how many epochs the world held the transitioned state,
  # and whether it left that state before its last sample.
  #
  # "In the transitioned state" is the rule `transition_epoch` itself is read by, applied
  # sample by sample (`Lab::TransitionRule`): `compress_ratio` at or below the fraction of
  # the run's own baseline, with no alphabet collapse (docs/design_record.md, 2026-10-01).
  # Every sample at or after a transition lies outside the baseline window by construction
  # — the tracker reads nothing until the window closes — so the relative predicate is well
  # defined over the whole span this reads, and a run that has no baseline has no reading
  # at all. Leaving the state is read with the tracker's hold in reverse: the state ends at
  # the first of `hold_samples + 1` consecutive samples the rule rejects, so a single
  # sample flickering back above the threshold is no more a relapse than a single sample
  # below it is a transition. A state that never ends persisted to the last sample.
  #
  # A descendant has no transition of its own: its colony was established when it started
  # from its parent's world, so it is read from `parent_epoch` on. It has no baseline of
  # its own either — it starts past the window — so it is read against the baseline of
  # the founding run whose random start its world continues (docs/design_record.md,
  # 2026-10-01): under its parent's params and seed it is the parent carried on, and reads
  # as the parent would.
  #
  # It reads stored samples and changes nothing — not the detector, not a metric, not a run.
  class PersistenceSummaryService
    include Callable

    def initialize(run:)
      @run = run
    end

    def call
      return nil if anchor.nil? || baseline.nil? || transitioned_samples.empty?

      Persistence.new(census_peak: census_peak, peak_epoch: peak_epoch,
                      epochs_persisted: epochs_persisted, relapsed: exit_index.present?)
    end

    private

    def anchor = @run.descendant? ? @run.parent_epoch : @run.transition_epoch

    def samples = @samples ||= @run.samples.order(:epoch).pluck(:epoch, :values)

    def baseline
      return @baseline if defined?(@baseline)

      @baseline = Lab::TransitionRule.baseline_of(@run.descendant? ? founding_baseline_samples : samples)
    end

    def founding_baseline_samples
      founding = @run
      founding = founding.parent_run while founding.descendant?

      founding.samples.where(epoch: ..Lab::TransitionRule::BASELINE_EPOCHS).order(:epoch).pluck(:epoch, :values)
    end

    def transitioned?(values) = Lab::TransitionRule.qualifies_relative?(values, baseline: baseline)

    def transitioned_samples
      @transitioned_samples ||= samples.drop_while { |epoch, _| epoch < anchor }
    end

    def epochs_persisted = [persisted_through.to_i - anchor, 0].max

    # The last epoch the world was still in the transitioned state: the last sample the
    # rule accepts before the exit, or before the end of the series when there is none.
    def persisted_through
      held = exit_index ? transitioned_samples.take(exit_index) : transitioned_samples
      last = held.reverse.find { |_, values| transitioned?(values) }

      (last || transitioned_samples.first).first
    end

    def exit_index
      return @exit_index if defined?(@exit_index)

      qualifying = transitioned_samples.map { |_, values| transitioned?(values) }
      exit_samples = Persistence::EXIT_SAMPLES
      @exit_index = (0..(qualifying.size - exit_samples)).find { |index| qualifying[index, exit_samples].none? }
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
