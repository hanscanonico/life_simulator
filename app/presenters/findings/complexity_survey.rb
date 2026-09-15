# frozen_string_literal: true

module Findings
  # Every run the lab has that emerged — a crossing a replicator or a copy confirmed
  # (`docs/design_record.md`, 2026-09-15), not every crossing the detector flagged — read
  # through the complexity its samples record of the dominant replicator after that
  # crossing: the compressed length of that tape and how many instructions it executes
  # (`docs/design_record.md`, evolution programme rung 4).
  # A world whose replicator keeps getting more complicated is open-ended; one that found a
  # recipe and stopped has plateaued, and the two read differently here.
  #
  # This is a survey of runs that already exist rather than a sweep designed to ask it, so
  # it counts directions and never fits a trend.
  class ComplexitySurvey
    Row = Data.define(:run, :experiment, :series) do
      delegate :seed, :emergence_epoch, to: :run

      def readings = series.size

      def first_length = series.first[1]

      def last_length = series.last[1]

      def max_length = series.map { |reading| reading[1] }.max

      def first_epoch = series.first.first

      def last_epoch = series.last.first

      def first_instructions = series.first.last

      def last_instructions = series.last.last

      # Nothing to compare on a single reading: a run with one sample is neither growing
      # nor flat, it is unread.
      def direction
        return nil if readings < 2
        return :flat if last_length == first_length

        last_length > first_length ? :grew : :shrank
      end

      def compared? = !direction.nil?

      def grew? = direction == :grew

      def shrank? = direction == :shrank

      def flat? = direction == :flat
    end

    def self.build = new

    delegate :any?, to: :rows

    # One row per emerged run whose samples carry a complexity reading at or after its
    # confirmed crossing. A run whose replicators were never measured by an engine that
    # reports it has nothing to say here and gets no row.
    def rows
      @rows ||= emerged_runs.filter_map do |run|
        series = series_by_run[run.id]
        Row.new(run: run, experiment: run.experiment, series: series) if series.present?
      end
    end

    def emerged_count = emerged_runs.size

    # What the detector flagged, over the same terminal runs: the page prints both, because
    # most of the difference is the detector firing on a random fill settling.
    def flagged_count = @flagged_count ||= Run.transitioned.count

    def measured_count = rows.size

    def compared_rows = @compared_rows ||= rows.select(&:compared?)

    def compared_count = compared_rows.size

    def grew_count = compared_rows.count(&:grew?)

    def shrank_count = compared_rows.count(&:shrank?)

    def flat_count = compared_rows.count(&:flat?)

    def table_rows = rows.first(ShowPage::MAX_TRANSITIONS)

    def rows_omitted = [rows.size - ShowPage::MAX_TRANSITIONS, 0].max

    def capped? = rows_omitted.positive?

    def sweeps = @sweeps ||= rows.map(&:experiment).uniq.sort_by(&:name)

    private

    def emerged_runs
      @emerged_runs ||= Run.emerged.includes(:experiment)
                           .order(:experiment_id, :emergence_epoch, :id).to_a
    end

    # One query for the whole page. The type test keeps a sample the engine reported a null
    # length for — no tested tape replicated — out of the series, and the casts are safe
    # behind it; the two readings are written together, so the length decides the row.
    def series_by_run
      @series_by_run ||=
        Sample.joins(:run).where(run_id: emerged_runs.map(&:id))
              .where("samples.epoch >= runs.emergence_epoch")
              .where("jsonb_typeof(samples.values -> 'dominant_compressed_len') = 'number'")
              .order(:run_id, :epoch)
              .pluck(:run_id, :epoch,
                     Arel.sql("(samples.values ->> 'dominant_compressed_len')::numeric"),
                     Arel.sql("(samples.values ->> 'dominant_instruction_count')::numeric"))
              .group_by(&:first)
              .transform_values do |rows|
                rows.map { |(_, epoch, length, instructions)| [epoch, length.to_i, instructions.to_i] }
              end
    end
  end
end
