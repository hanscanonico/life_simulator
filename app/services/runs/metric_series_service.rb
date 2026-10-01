# frozen_string_literal: true

module Runs
  # One observable of one run as `[[epoch, value], …]` in epoch order. A sample that does
  # not carry the metric as a number contributes no point: the engine adds observables over
  # time, so an old run's samples are sparse rather than wrong.
  class MetricSeriesService
    include Callable

    # A caller drawing many series of one run hands in its rows, `[[epoch, values], …]`
    # in epoch order, so their JSON is parsed once rather than once per metric.
    def initialize(run:, metric:, samples: nil)
      @run = run
      @metric = metric
      @samples = samples
    end

    def call
      samples.filter_map do |epoch, values|
        value = values[@metric]
        [epoch, value] if value.is_a?(Numeric)
      end
    end

    private

    def samples = @samples ||= @run.samples.order(:epoch).pluck(:epoch, :values)
  end
end
