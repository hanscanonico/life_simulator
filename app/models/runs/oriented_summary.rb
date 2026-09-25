# frozen_string_literal: true

module Runs
  # What the orientation-aware census (#245, #247) says about one run: the share of its
  # soup held by self-replicators that copy in either orientation, read at the end, at its
  # peak, and from the first epoch it held a qualifying share. The locked census counts
  # only same-orientation copies, so this is a companion reading beside it; it relocks
  # nothing.
  #
  # Its readings come from two sources, kept apart: `stored` readings the corpus pass took
  # of the worlds the run kept (`snapshot_readings` under the instrument), and `live`
  # samples taken while the run ran, which carry the share only since #247. Stored worlds
  # are about every 1000 epochs apart, so for most runs every epoch here — the first above
  # all — is only as fine as that: the first reading at the share, not the first epoch the
  # world held it. A reading that lacks the share is no reading, never a zero.
  class OrientedSummary
    STORED = "stored"
    LIVE = "live"

    Reading = Data.define(:epoch, :share, :source)

    attr_reader :readings

    # `readings` are Reading values; where both sources read the same epoch the live
    # sample stands, being the world itself rather than a restored copy of it.
    def initialize(epochs:, readings:)
      @epochs = epochs
      @readings = readings.select { |reading| reading.share.is_a?(Numeric) }
                          .sort_by { |reading| [reading.epoch, reading.source == LIVE ? 1 : 0] }
                          .reverse.uniq(&:epoch).reverse
    end

    def measured? = readings.any?

    def stored_count = readings.count { |reading| reading.source == STORED }

    def live_count = readings.count { |reading| reading.source == LIVE }

    def terminal_share = readings.find { |reading| reading.epoch == @epochs }&.share

    def peak_share = peak&.share

    def peak_epoch = peak&.epoch

    def first_replicator_epoch = first_replicator&.epoch

    # Nil where the run never reached the share: there is nothing it could have held.
    def held
      return if first_replicator.nil?

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
