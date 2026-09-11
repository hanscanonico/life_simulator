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
    # Where the rotated y title sits, measured from the left of the viewBox. It is fixed
    # inside the left gutter on purpose: derived from the tick labels' own extent it lands
    # outside the viewBox — and is clipped — on a chart whose ticks are one digit wide.
    Y_TITLE_X = 18

    Tick = Data.define(:label, :position)

    def width = WIDTH
    def height = HEIGHT
    def plot_left = PADDING[:left]
    def plot_top = PADDING[:top]
    def plot_right = WIDTH - PADDING[:right]
    def plot_bottom = HEIGHT - PADDING[:bottom]
    def plot_width = plot_right - plot_left
    def plot_height = plot_bottom - plot_top

    # How far the data itself is pulled back from the axis lines. The outermost marks of a
    # phase diagram are whole dots, not a line's endpoint, so half of one sits outside the
    # plot box unless the columns are inset the way their labels are.
    def x_inset = 0

    def x_axis_width = plot_width - (2 * x_inset)
    def y_title_x = Y_TITLE_X
    def y_title_y = plot_top + (plot_height / 2)

    def x_ticks = x_scale.ticks.map { |tick| tick.with(position: plot_left + tick.position) }
    def y_ticks = y_scale.ticks.map { |tick| tick.with(position: plot_top + tick.position) }

    # A word-long label centred on the plot's edge ("well-mixed" at the far end of the
    # radius axis) spills outside the viewBox and is clipped, so the outermost x labels
    # hug the edge instead of straddling it.
    def x_tick_anchor(position)
      return "start" if position <= plot_left + EDGE_INSET
      return "end" if position >= plot_right - EDGE_INSET

      "middle"
    end

    def x_tick_label_x(position) = position.clamp(plot_left + EDGE_INSET, plot_right - EDGE_INSET)

    def x_pixel(value) = plot_left + x_inset + x_scale.position(value)
    def y_pixel(value) = plot_top + y_scale.position(value)
  end
end
