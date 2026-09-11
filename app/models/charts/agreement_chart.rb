# frozen_string_literal: true

module Charts
  # Where the transition detector and the replicator census disagree, arm by arm: three
  # bars per arm — runs only the detector flagged, runs where only the census counted a
  # replicator, and runs the two agreed on.
  #
  # The bars are drawn from Experiments::TransitionArmsService::Arm, the same rows the
  # per-arm table beside the chart prints, so the picture and the numbers cannot drift
  # apart on what "disagree" means (DESIGN.md §1.2).
  class AgreementChart
    include Plot

    Series = Data.define(:key, :name, :count)

    SERIES = [Series.new(key: "flagged", name: "Flagged only", count: :flagged_only),
              Series.new(key: "replicated", name: "Replicators only", count: :replicated_only),
              Series.new(key: "both", name: "Both", count: :both)].freeze

    # The share of an arm's band the bars take, the rest being the gutter between arms.
    GROUP_FILL = 0.78
    # An eight-character arm label spans a sixth of the 668-unit axis at phone width, so
    # past six arms not all of them can be named.
    MAX_LABELLED_ARMS = 6
    # Half the widest arm label: a label whose band centre sits this close to an end of
    # the axis is hung off that end instead of straddling its band, where it would reach
    # over the y labels or past the frame.
    LABEL_ROOM = 60

    Bar = Data.define(:x, :y, :width, :height, :series, :label)

    def initialize(arms:, title:)
      @arms = arms
      @title = title
    end

    attr_reader :arms, :title

    def to_partial_path = "charts/agreement_chart"

    def x_label = "Arm"

    def y_label = "Runs"

    def series = SERIES

    def empty? = bar_counts.all?(&:zero?)

    def bars
      @arms.each_with_index.flat_map do |arm, index|
        SERIES.each_with_index.map { |bar_series, slot| bar(arm, index, bar_series, slot) }
      end
    end

    # A sweep has a handful of arms, so every one of them is its own tick; a grid too long
    # to label names every second or third arm, and the table beside the chart carries the
    # rest.
    def x_ticks
      @arms.each_with_index.select { |_, index| (index % label_stride).zero? }
           .map { |arm, index| Plot::Tick.new(label: arm.label, position: group_centre(index)) }
    end

    def x_tick_anchor(position)
      return "start" if position < plot_left + LABEL_ROOM
      return "end" if position > plot_right - LABEL_ROOM

      "middle"
    end

    def x_tick_label_x(position)
      return [position, plot_left + EDGE_INSET].max if position < plot_left + LABEL_ROOM
      return [position, plot_right - EDGE_INSET].min if position > plot_right - LABEL_ROOM

      position
    end

    # There are no half-runs: an arm whose tallest bar is a single run would otherwise be
    # measured in fifths of one.
    def y_ticks = super.select { |tick| (tick.value % 1).zero? }

    def y_scale = @y_scale ||= Scale.new(values: [0.0, tallest_bar], length: plot_height, flip: true)

    private

    def bar(arm, index, series, slot)
      count = arm.public_send(series.count)
      top = y_pixel(count)

      Bar.new(x: bar_left(index, slot), y: top, width: bar_width, height: plot_bottom - top,
              series: series, label: bar_label(arm, series, count))
    end

    def bar_label(arm, series, count)
      "#{arm.label} — #{series.name.downcase}: #{count} of #{arm.runs} sampled runs"
    end

    def bar_left(index, slot) = group_left(index) + (slot * bar_width)

    def bar_width = group_width / SERIES.size

    def group_width = band_width * GROUP_FILL

    def group_left(index) = plot_left + (index * band_width) + ((band_width - group_width) / 2)

    def group_centre(index) = plot_left + ((index + 0.5) * band_width)

    def band_width = plot_width.fdiv([@arms.size, 1].max)

    def label_stride = [(@arms.size / MAX_LABELLED_ARMS.to_f).ceil, 1].max

    def bar_counts = @arms.flat_map { |arm| SERIES.map { |series| arm.public_send(series.count) } }

    # The tallest bar, not the largest arm: the y axis measures the three counts drawn, so
    # a sweep where the two observables mostly agree still fills the plot.
    def tallest_bar = [bar_counts.max.to_f, 1.0].max
  end
end
