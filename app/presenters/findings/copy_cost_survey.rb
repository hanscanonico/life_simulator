# frozen_string_literal: true

module Findings
  # Every transitioned run the lab has, read through the copy cost its samples carry after
  # the crossing: the interpreter steps the dominant replicator needs for one byte-exact
  # copy (`docs/design_record.md`, evolution programme rung 3). A colony that copies itself
  # for fewer steps than it used to is the plainest thing adaptation could look like here.
  #
  # This is a survey of runs that already exist rather than the adaptation sweep: the runs
  # come from different grids at different budgets, so it counts directions and never fits
  # a trend.
  class CopyCostSurvey
    Row = Data.define(:run, :experiment, :costs) do
      delegate :seed, :transition_epoch, to: :run

      def readings = costs.size

      def first_cost = costs.first.last

      def last_cost = costs.last.last

      def first_epoch = costs.first.first

      def last_epoch = costs.last.first

      def min_cost = costs.map(&:last).min

      # Nothing to compare on a single reading: a run with one sample is neither falling
      # nor flat, it is unread.
      def direction
        return nil if readings < 2
        return :flat if last_cost == first_cost

        last_cost < first_cost ? :fell : :rose
      end

      def compared? = !direction.nil?

      def fell? = direction == :fell

      def rose? = direction == :rose

      def flat? = direction == :flat
    end

    def self.build = new

    delegate :any?, to: :rows

    # One row per transitioned run whose samples carry a copy cost at or after its
    # crossing. A run whose replicators were never tested by an engine that reports the
    # cost has nothing to say here and gets no row.
    def rows
      @rows ||= transitioned_runs.filter_map do |run|
        costs = costs_by_run[run.id]
        Row.new(run: run, experiment: run.experiment, costs: costs) if costs.present?
      end
    end

    def transitioned_count = transitioned_runs.size

    def measured_count = rows.size

    def compared_rows = @compared_rows ||= rows.select(&:compared?)

    def compared_count = compared_rows.size

    def fell_count = compared_rows.count(&:fell?)

    def rose_count = compared_rows.count(&:rose?)

    def flat_count = compared_rows.count(&:flat?)

    def table_rows = rows.first(ShowPage::MAX_TRANSITIONS)

    def rows_omitted = [rows.size - ShowPage::MAX_TRANSITIONS, 0].max

    def capped? = rows_omitted.positive?

    def sweeps = @sweeps ||= rows.map(&:experiment).uniq.sort_by(&:name)

    private

    def transitioned_runs
      @transitioned_runs ||= Run.transitioned.includes(:experiment)
                                .order(:experiment_id, :transition_epoch, :id).to_a
    end

    # One query for the whole page. The type test keeps a sample the engine reported a null
    # cost for — no tested tape replicated — out of the series, and the cast is safe behind
    # it.
    def costs_by_run
      @costs_by_run ||=
        Sample.joins(:run).where(run_id: transitioned_runs.map(&:id))
              .where("samples.epoch >= runs.transition_epoch")
              .where("jsonb_typeof(samples.values -> 'copy_cost') = 'number'")
              .order(:run_id, :epoch)
              .pluck(:run_id, :epoch, Arel.sql("(samples.values ->> 'copy_cost')::numeric"))
              .group_by(&:first)
              .transform_values { |rows| rows.map { |(_, epoch, cost)| [epoch, cost.to_i] } }
    end
  end
end
