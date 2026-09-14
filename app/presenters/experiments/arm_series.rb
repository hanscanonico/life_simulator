# frozen_string_literal: true

module Experiments
  # The lineage and complexity observables of one swept axis, arm against arm: at every
  # sampled epoch, the mean over the runs of an arm of what the engine recorded there. The
  # run pages answer "what became of descent, and of the dominant replicator" one run at a
  # time; a sweep asks what its parameter did to them.
  #
  # The engine is the only authority on these metrics (DESIGN §1.2): everything here is an
  # average over stored samples, and nothing is derived from a tape.
  class ArmSeries
    # The aggregate is spelled out per metric rather than built around the metric's name:
    # no SQL on this page is assembled from a variable.
    Series = Data.define(:metric, :title, :average)

    LINEAGE = [
      Series.new(metric: "distinct_lineages", title: "Distinct lineages",
                 average: "AVG((values ->> 'distinct_lineages')::numeric)"),
      Series.new(metric: "top_lineage_share", title: "Share of the largest lineage",
                 average: "AVG((values ->> 'top_lineage_share')::numeric)")
    ].freeze

    COMPLEXITY = [
      Series.new(metric: "dominant_compressed_len",
                 title: "Compressed length of the dominant replicator (bytes)",
                 average: "AVG((values ->> 'dominant_compressed_len')::numeric)"),
      Series.new(metric: "dominant_instruction_count", title: "Instructions in the dominant replicator",
                 average: "AVG((values ->> 'dominant_instruction_count')::numeric)")
    ].freeze

    def self.build(axis:, runs:) = new(axis: axis, runs: runs)

    def initialize(axis:, runs:)
      @axis = axis
      @runs = runs
    end

    def lineage_charts = @lineage_charts ||= charts_for(LINEAGE)

    def complexity_charts = @complexity_charts ||= charts_for(COMPLEXITY)

    def any? = lineage_charts.any? || complexity_charts.any?

    private

    # A sweep whose runs were measured by an engine that did not report an observable yet —
    # or that nothing has been sampled from at all — draws no chart for it rather than an
    # empty frame.
    def charts_for(group)
      group.filter_map do |series|
        chart = Charts::ArmLines.new(arms: arms_for(series), y_label: series.title,
                                     title: "#{series.title} vs epoch, per arm of #{@axis.prose_name}")
        chart unless chart.empty?
      end
    end

    def arms_for(series)
      @axis.values.map do |value|
        Charts::ArmLines::Arm.new(label: @axis.label_of(value), points: means_for(run_ids_at(value), series))
      end
    end

    def run_ids_at(value) = @runs.select { |run| @axis.matches?(run.params, value) }.map(&:id)

    # Averaged in Postgres, one query per arm and series: a sweep's runs carry thousands of
    # samples each, and the page draws only the arm's mean at each epoch. The type test
    # keeps a sample whose reading the engine reported as null — nothing replicated — out
    # of the mean, and makes the cast behind it safe.
    def means_for(run_ids, series)
      return [] if run_ids.empty?

      Sample.where(run_id: run_ids)
            .where("jsonb_typeof(values -> ?) = 'number'", series.metric)
            .group(:epoch).order(:epoch)
            .pluck(:epoch, Arel.sql(series.average))
    end
  end
end
