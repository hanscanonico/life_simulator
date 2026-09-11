# frozen_string_literal: true

module Runs
  # One observable of one run as `[[epoch, value], …]` in epoch order. A sample that does
  # not carry the metric as a number contributes no point: the engine adds observables over
  # time, so an old run's samples are sparse rather than wrong.
  class MetricSeriesService
    include Callable

    def initialize(run:, metric:)
      @run = run
      @metric = metric
    end

    def call
      samples.filter_map do |epoch, values|
        value = values[@metric]
        [epoch, value] if value.is_a?(Numeric)
      end
    end

    private

    # A page drawing every observable asks for the same rows once per metric; identical
    # SQL inside one request is served by the query cache.
    def samples = @run.samples.order(:epoch).pluck(:epoch, :values)
  end
end
