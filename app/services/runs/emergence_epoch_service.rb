# frozen_string_literal: true

module Runs
  # The one place the confirmation rule is spelled out: a crossing reads `compress_ratio`
  # and nothing else (DESIGN.md §1.2), so it is a *candidate*, and
  # a run emerged only when the replicator census or the copy rate is positive within
  # CONFIRM_WINDOW samples of it. A crossing no witness backs — the random fill settling
  # into a compressible soup with no copier in it — yields nothing.
  #
  # Every crossing the samples hold is a candidate, not only the one the detector stored:
  # the first one can be that false positive while a real emergence follows it ten thousand
  # epochs later (run 543, docs/design_record.md 2026-09-15). The stored crossing is read
  # first and stays the detector's own, and the earliest crossing a witness backs is the
  # answer.
  #
  # The crossings read here are the constant rule's, which the 2026-09-21 relock left
  # where they were: what makes an emergence is the witness, and the rule that gates the
  # candidates cannot be the relative one — it reads no crossing inside its own baseline
  # window and no second crossing against an uncontaminated baseline.
  #
  # It reads stored samples and changes nothing; the caller stores what it returns.
  class EmergenceEpochService
    include Callable

    # Chosen as 10 samples on either side of the crossing; re-measure it over the corpus if
    # the sampling interval or the detector's hold changes.
    CONFIRM_WINDOW = 10

    # `samples` is the run's stored samples as [epoch, values] in epoch order, passed in by
    # a caller that already read them for a whole experiment and read here otherwise.
    def initialize(run: nil, transition_epoch: run&.transition_epoch_constant, samples: nil)
      @run = run
      @transition_epoch = transition_epoch
      @samples = samples
    end

    def call
      candidates.each do |epoch|
        witness = confirming_observable(window_around(epoch))

        return Emergence.new(epoch: epoch, witness: witness) if witness
      end

      Emergence.none
    end

    private

    # A run the detector never flagged is not a candidate for anything: the first crossing
    # stays the gate on emergence, and only the crossings after it are read beside it.
    def candidates
      return [] if @transition_epoch.nil?

      [@transition_epoch, *later_crossings]
    end

    def later_crossings
      CrossingsService.call(samples: samples).select { |epoch| epoch > @transition_epoch }
    end

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
