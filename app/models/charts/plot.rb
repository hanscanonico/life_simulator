# frozen_string_literal: true

module Charts
  # The frame every chart shares: a fixed viewBox, a padded plot area and the two scales
  # the partials read to place gridlines, ticks and marks.
  module Plot
    # The padding is where the labels live, so it holds the largest text the charts draw:
    # 23 user units at phone width (site.css). An eight-character y label is 110 units wide
    # at that size and hangs 8 units left of the plot, hence a 120-unit left gutter; the
    # bottom one stacks the x labels and the axis title, and the top one takes the ascent of
    # the highest y label.
    WIDTH = 828
    HEIGHT = 328
    PADDING = { top: 24, right: 40, bottom: 64, left: 120 }.freeze
    # How far the outermost x labels are pulled back inside the plot. At phone width a
    # label is 23 units tall, and the two ends of the axis are the crowded places: the
    # last one all but touches the card border, and the first shares the origin with the y
    # axis's own zero.
    EDGE_INSET = 14

    Tick = Data.define(:label, :position)

    def width = WIDTH
    def height = HEIGHT
    def plot_left = PADDING[:left]
    def plot_top = PADDING[:top]
    def plot_right = WIDTH - PADDING[:right]
    def plot_bottom = HEIGHT - PADDING[:bottom]
    def plot_width = plot_right - plot_left
    def plot_height = plot_bottom - plot_top

    def x_ticks = x_scale.ticks.map { |tick| tick.with(position: plot_left + tick.position) }
    def y_ticks = y_scale.ticks.map { |tick| tick.with(position: plot_top + tick.position) }

    # A word-long label centred on the plot's edge ("well-mixed" at the far end of the
    # radius axis) spills outside the viewBox and is clipped, so the outermost x labels
    # hug the edge instead of straddling it.
    def x_tick_anchor(position)
      return "start" if position <= plot_left
      return "end" if position >= plot_right

      "middle"
    end

    def x_tick_label_x(position)
      return position + EDGE_INSET if position <= plot_left
      return position - EDGE_INSET if position >= plot_right

      position
    end

    def x_pixel(value) = plot_left + x_scale.position(value)
    def y_pixel(value) = plot_top + y_scale.position(value)
  end
end
