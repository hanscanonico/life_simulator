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
    Series = Data.define(:metric, :title)

    LINEAGE = [
      Series.new(metric: "distinct_lineages", title: "Distinct lineages"),
      Series.new(metric: "top_lineage_share", title: "Share of the largest lineage")
    ].freeze

    COMPLEXITY = [
      Series.new(metric: "dominant_compressed_len", title: "Compressed length of the dominant tape (bytes)"),
      Series.new(metric: "dominant_instruction_count", title: "Instructions in the dominant tape"),
      Series.new(metric: "lineage_compressed_len", title: "Compressed length of the largest lineage's tape (bytes)"),
      Series.new(metric: "lineage_instruction_count", title: "Instructions in the largest lineage's tape")
    ].freeze

    EVERY = (LINEAGE + COMPLEXITY).freeze

    def self.build(axis:, runs:) = new(axis: axis, means: ArmMeans.read(axes: [axis], runs: runs, series: EVERY))

    # Every axis of a sweep drawn off the one read of its samples ArmMeans makes.
    def self.for_axes(axes:, means:) = axes.index_with { |axis| new(axis: axis, means: means) }

    def initialize(axis:, means:)
      @axis = axis
      @means = means
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
        Charts::ArmLines::Arm.new(label: @axis.label_of(value), points: points_at(value, series))
      end
    end

    def points_at(value, series) = @means.fetch([@axis.name, @axis.values.index(value), series.metric], [])
  end
end
