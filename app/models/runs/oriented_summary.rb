# frozen_string_literal: true

module Runs
  # What the orientation-aware census (#245, #247) says about one run: the share of its
  # soup held by self-replicators that copy in either orientation, read at the end, at its
  # peak, and from the first reading at a qualifying share. The locked census counts only
  # same-orientation copies, so this is a companion reading beside it; it relocks nothing.
  #
  # Its readings are the corpus pass's static readings of the worlds the run kept (see
  # OrientedSummariesService), so every run is read at the same cadence: the first and
  # last world, one about every 1000 epochs, and the one nearest the transition. Every
  # epoch here — the first replicator epoch above all — is only as fine as that: the first
  # reading at the share, not the first epoch the world held it. A reading that lacks the
  # share is no reading, never a zero.
  class OrientedSummary
    Reading = Data.define(:epoch, :share)

    attr_reader :readings

    def initialize(epochs:, readings:)
      @epochs = epochs
      @readings = readings.select { |reading| reading.share.is_a?(Numeric) }.sort_by(&:epoch)
    end

    def measured? = readings.any?

    def terminal_share = readings.find { |reading| reading.epoch == @epochs }&.share

    def peak_share = peak&.share

    def peak_epoch = peak&.epoch

    def first_replicator_epoch = first_replicator&.epoch

    # Whether every reading from the first replicator one to the run's last world holds
    # the share. Nil where the run never reached it, or where its last world was never
    # read: without an end there is no telling whether it held to it.
    def held
      return if first_replicator.nil? || terminal_share.nil?

      readings.drop_while { |reading| reading.epoch < first_replicator.epoch }.all? { |reading| qualifies?(reading) }
    end

    def replicator_world? = peak_share.present? && peak_share >= qualifying_share

    def held_to_end? = terminal_share.present? && terminal_share >= qualifying_share

    private

    def peak = @peak ||= readings.max_by(&:share)

    def first_replicator = @first_replicator ||= readings.find { |reading| qualifies?(reading) }

    def qualifies?(reading) = reading.share >= qualifying_share

    def qualifying_share = Lab::DescendantReading::QUALIFYING_SHARE
  end
end
