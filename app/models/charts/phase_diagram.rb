# frozen_string_literal: true

module Charts
  # Transition epoch against one swept parameter: a run whose crossing a replicator
  # confirmed is a filled dot, a crossing the detector flagged and nothing confirmed is a
  # hollow dot at the epoch it was flagged, and the median per parameter value is the line
  # through the confirmed ones. Runs with no confirmed emergence — the flagged-only ones
  # among them — are counted along the top of the plot (they have no y value, only a lower
  # bound), so the top row and the arm table's censored column are the same runs.
  class PhaseDiagram
    include Plot

    CENSORED_ROW = 10
    # An eight-character label spans a sixth of the 668-unit axis, and a log axis packs its
    # columns unevenly, so past six values not all of them can be named.
    MAX_LABELLED_VALUES = 6

    Group = Data.define(:value, :label, :emergence_epochs, :flagged_only_epochs, :censored) do
      def median
        return nil if emergence_epochs.empty?

        sorted = emergence_epochs.sort
        middle = sorted.size / 2
        sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
      end
    end

    def initialize(groups:, title:, x_label:, epochs:, log_x: false)
      @groups = groups
      @title = title
      @x_label = x_label
      @epochs = epochs
      @log_x = log_x
    end

    attr_reader :groups, :title, :x_label, :epochs

    def to_partial_path = "charts/phase_diagram"

    def y_label = "Transition epoch"

    def empty?
      @groups.all? do |group|
        group.emergence_epochs.empty? && group.flagged_only_epochs.empty? && group.censored.zero?
      end
    end

    def dots
      marks(:emergence_epochs) { |group, epoch| "#{group.label}: emerged at epoch #{epoch}" }
    end

    # The crossings the detector flagged that no replicator confirmed: still drawn, since
    # the sweep was run to find them, but never filled and never in the median.
    def flagged_dots
      marks(:flagged_only_epochs) { |group, epoch| "#{group.label}: flagged at epoch #{epoch}, unconfirmed" }
    end

    # A sweep has a handful of grid values, so every one of them is its own tick: nice
    # round ticks would sit between the columns the reader is comparing. A grid too long to
    # label names every other value; the dots and the arm table still carry the rest.
    def x_ticks
      sorted = @groups.sort_by(&:value)
      sorted = sorted.select.with_index { |_, index| index.even? } if sorted.size > MAX_LABELLED_VALUES
      sorted.map { |group| Plot::Tick.new(label: group.label, position: x_pixel(group.value)) }
    end

    def median_path
      points = @groups.select(&:median).sort_by(&:value)
      points.map.with_index do |group, index|
        "#{index.zero? ? 'M' : 'L'}#{x_pixel(group.value).round(2)},#{y_pixel(group.median).round(2)}"
      end.join(" ")
    end

    def censored_marks
      @groups.select { |group| group.censored.positive? }.map do |group|
        { x: x_pixel(group.value), y: plot_top + CENSORED_ROW, count: group.censored, label: censored_label(group) }
      end
    end

    def censored_label(group)
      runs = group.emergence_epochs.size + group.censored
      "#{group.label}: no emergence in #{epochs} epochs (#{group.censored} of #{runs} runs)"
    end

    def x_inset = EDGE_INSET

    def x_scale
      @x_scale ||= Scale.new(values: @groups.map(&:value), length: x_axis_width, log: @log_x)
    end

    def y_scale
      @y_scale ||= Scale.new(values: [0.0, *transition_epochs_or_span], length: plot_height, flip: true)
    end

    private

    def marks(field)
      @groups.flat_map do |group|
        group.public_send(field).map do |epoch|
          { x: x_pixel(group.value), y: y_pixel(epoch), label: yield(group, epoch) }
        end
      end
    end

    def transition_epochs_or_span
      epochs = @groups.flat_map { |group| group.emergence_epochs + group.flagged_only_epochs }
      epochs.presence || [@epochs.to_f]
    end
  end
end
