# frozen_string_literal: true

module Charts
  # One metric against epochs: a polyline, two labelled axes and an optional vertical
  # marker (the transition epoch).
  class LineChart
    include Plot

    def initialize(points:, title:, x_label:, y_label:, log_x: false, marker: nil)
      @points = points.map { |x, y| [x.to_f, y.to_f] }.sort_by(&:first)
      @title = title
      @x_label = x_label
      @y_label = y_label
      @log_x = log_x
      @marker = marker
    end

    attr_reader :title, :x_label, :y_label, :marker

    def to_partial_path = "charts/line_chart"

    def empty? = @points.none?

    def path
      @points.map.with_index do |(x, y), index|
        "#{index.zero? ? 'M' : 'L'}#{x_pixel(x).round(2)},#{y_pixel(y).round(2)}"
      end.join(" ")
    end

    def marker_pixel
      return nil if empty? || @marker.nil? || !@marker.to_f.between?(x_scale.min, x_scale.max)

      x_pixel(@marker)
    end

    def x_scale
      @x_scale ||= Scale.new(values: @points.map(&:first), length: plot_width, log: @log_x)
    end

    def y_scale
      @y_scale ||= Scale.new(values: [0.0, *@points.map(&:last)], length: plot_height, flip: true)
    end
  end
end
