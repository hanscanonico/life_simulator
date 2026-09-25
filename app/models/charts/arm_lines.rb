# frozen_string_literal: true

module Charts
  # One observable against epochs, one line per arm of a sweep: the picture a run page
  # draws of a single run, drawn instead for every arm at once so a parameter's effect on
  # the observable can be read off the sweep itself.
  #
  # The points are what the engine already recorded, averaged over the runs of an arm
  # (Experiments::ArmSeries); nothing here derives a metric of its own.
  class ArmLines
    include Plot

    Arm = Data.define(:label, :points)

    Line = Data.define(:label, :dash, :path)

    def initialize(arms:, title:, y_label:)
      @arms = arms.map { |arm| arm.with(points: arm.points.map { |x, y| [x.to_f, y.to_f] }.sort_by(&:first)) }
      @title = title
      @y_label = y_label
    end

    attr_reader :arms, :title, :y_label

    def to_partial_path = "charts/arm_lines"

    def x_label = "Epoch"

    def empty? = drawn_arms.none?

    # Drawn once: the partial reads the lines for the plot and again for the legend, and a
    # path through every sampled epoch of an arm is most of a sweep page's render.
    def lines
      @lines ||= drawn_arms.map.with_index do |arm, index|
        Line.new(label: arm.label, dash: dash_for(index), path: draw(arm.points))
      end
    end

    def x_scale = @x_scale ||= Scale.new(values: [0.0, *every_point.map(&:first)], length: plot_width)

    def y_scale = @y_scale ||= Scale.new(values: [0.0, *every_point.map(&:last)], length: plot_height, flip: true)

    private

    # An arm nothing has been sampled from is no line at all rather than a flat zero.
    def drawn_arms = @drawn_arms ||= arms.reject { |arm| arm.points.empty? }

    def every_point = @every_point ||= drawn_arms.flat_map(&:points)

    def draw(points)
      points.map.with_index do |(x, y), index|
        "#{index.zero? ? 'M' : 'L'}#{x_pixel(x).round(2)},#{y_pixel(y).round(2)}"
      end.join(" ")
    end
  end
end
