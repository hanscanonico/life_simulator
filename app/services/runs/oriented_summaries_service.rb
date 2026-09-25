# frozen_string_literal: true

module Runs
  # The orientation-aware summary (Runs::OrientedSummary) of every run given, keyed by run
  # id, in two queries whatever their number: one over the corpus pass's stored readings,
  # one over the live samples that carry the share. The runs must be loaded with `epochs`.
  #
  # The samples query is served by `index_samples_on_run_id_oriented`, whose predicate
  # SHARE_PRESENT has to keep matching: only samples taken since #247 carry the share, and
  # without it the query would read every sample the runs ever stored.
  class OrientedSummariesService
    include Callable

    INSTRUMENT = Lab::DescendantReading::INSTRUMENT
    # Lab::DescendantReading::SHARE_KEY, read as jsonb so a stored number stays a number.
    SHARE = "values -> 'replicator_share'"
    SHARE_PRESENT = "(#{SHARE}) IS NOT NULL".freeze

    def initialize(runs:)
      @runs = runs
    end

    def call
      readings = stored_readings.merge(live_readings) { |_, stored, live| stored + live }

      @runs.to_h { |run| [run.id, OrientedSummary.new(epochs: run.epochs, readings: readings.fetch(run.id, []))] }
    end

    private

    def run_ids = @run_ids ||= @runs.map(&:id)

    def stored_readings
      readings_of(SnapshotReading.where(run_id: run_ids, instrument: INSTRUMENT), OrientedSummary::STORED)
    end

    def live_readings = readings_of(Sample.where(run_id: run_ids), OrientedSummary::LIVE)

    def readings_of(scope, source)
      scope.where(SHARE_PRESENT).pluck(:run_id, :epoch, Arel.sql(SHARE))
           .group_by(&:first)
           .transform_values do |rows|
             rows.map { |(_, epoch, value)| OrientedSummary::Reading.new(epoch: epoch, share: value, source: source) }
           end
    end
  end
end
