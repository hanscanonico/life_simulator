# frozen_string_literal: true

module Charts
  # The frame every chart shares: a fixed viewBox, a padded plot area and the two scales
  # the partials read to place gridlines, ticks and marks.
  module Plot
    WIDTH = 760
    HEIGHT = 300
    PADDING = { top: 16, right: 20, bottom: 44, left: 72 }.freeze

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

    def x_pixel(value) = plot_left + x_scale.position(value)
    def y_pixel(value) = plot_top + y_scale.position(value)
  end
end
