# frozen_string_literal: true

module Experiments
  # One swept axis of a `param_grid`: the key whose list holds more than one value.
  #
  # A grid value can be a Hash (paired parameters, e.g. a square world's width and
  # height), in which case the runs carry the pair and not the axis name — matching a run
  # to a value means matching that sub-hash against the run's params.
  Axis = Data.define(:name, :values) do
    def param_keys = paired? ? values.first.keys : [name]

    def paired? = values.first.is_a?(Hash)

    def value_of(run_params) = values.find { |value| matches?(run_params, value) }

    def matches?(run_params, value)
      return value.all? { |key, paired| run_params[key] == paired } if value.is_a?(Hash)

      run_params[name] == value
    end

    # Non-numeric grids (an instruction-set ablation, `init`) have no position of their
    # own, so they fall back to their rank in the grid.
    def position_of(value)
      numeric = numeric_of(value)
      numeric || values.index(value).to_f
    end

    def label_of(value)
      return value.values.map { |paired| Charts.format_value(paired.to_f) }.uniq.join("×") if value.is_a?(Hash)

      value.is_a?(Numeric) ? Charts.format_value(value.to_f) : value.to_s
    end

    # More than two decades of span (the mutation-rate grid) is unreadable on a linear
    # axis: every value but the largest collapses onto the origin.
    def log?
      positive = values.map { |value| position_of(value) }.select(&:positive?)
      return false if positive.size < 2

      positive.max / positive.min > 100
    end

    def title = "Transition epoch vs #{name.to_s.humanize.downcase}"

    private

    def numeric_of(value)
      candidate = value.is_a?(Hash) ? value.values.find { |paired| paired.is_a?(Numeric) } : value
      candidate.is_a?(Numeric) ? candidate.to_f : nil
    end
  end
end
