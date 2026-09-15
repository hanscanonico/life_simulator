# frozen_string_literal: true

module Runs
  # The one place the confirmation rule is spelled out: `transition_epoch` reads
  # `compress_ratio` and nothing else (DESIGN.md §1.2), so a crossing is a *candidate*, and
  # a run emerged only when the replicator census or the copy rate is positive within
  # CONFIRM_WINDOW samples of it. A crossing no witness backs — the random fill settling
  # into a compressible soup with no copier in it — yields nothing.
  #
  # It reads stored samples and changes nothing; the caller stores what it returns.
  class EmergenceEpochService
    include Callable

    # Chosen as 10 samples on either side of the crossing; re-measure it over the corpus if
    # the sampling interval or the detector's hold changes.
    CONFIRM_WINDOW = 10

    # `samples` is the run's stored samples as [epoch, values] in epoch order, passed in by
    # a caller that already read them for a whole experiment and read here otherwise.
    def initialize(run: nil, transition_epoch: run&.transition_epoch, samples: nil)
      @run = run
      @transition_epoch = transition_epoch
      @samples = samples
    end

    def call
      return Emergence.none if @transition_epoch.nil?

      witness = confirming_observable(window_around(@transition_epoch))
      return Emergence.none if witness.nil?

      Emergence.new(epoch: @transition_epoch, witness: witness)
    end

    private

    def samples = @samples ||= @run ? @run.samples.order(:epoch).pluck(:epoch, :values) : []

    def window_around(epoch)
      index = samples.index { |(sample_epoch, _)| sample_epoch >= epoch }
      return [] if index.nil?

      samples[[index - CONFIRM_WINDOW, 0].max..(index + CONFIRM_WINDOW)]
    end

    def confirming_observable(window)
      return Emergence::CENSUS if positive_in?(window, "replicator_count")

      Emergence::COPY_RATE if positive_in?(window, "copy_rate")
    end

    def positive_in?(window, observable)
      window.any? { |(_, values)| values[observable].to_f.positive? }
    end
  end
end
