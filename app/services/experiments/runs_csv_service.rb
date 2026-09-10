# frozen_string_literal: true

require "csv"

module Experiments
  # Every run of a sweep as CSV lines: the seeds, the swept parameters and the last
  # sample's observables, so a finding's raw runs can be re-analysed outside the site
  # (DESIGN.md §1.3). Yields an enumerator, one line at a time.
  class RunsCsvService
    include Callable

    COLUMNS = %w[run_id seed status epochs epochs_done transition_epoch].freeze

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Enumerator.new do |lines|
        lines << CSV.generate_line(COLUMNS + param_keys + Sample::OBSERVABLES)
        @experiment.runs.find_each { |run| lines << CSV.generate_line(row(run)) }
      end
    end

    private

    def param_keys = @param_keys ||= Axis.sweep(@experiment.param_grid).flat_map(&:param_keys).uniq

    def row(run)
      [run.id, run.seed, run.status, run.epochs, run.epochs_done, run.transition_epoch] +
        param_keys.map { |key| run.params[key] } +
        Sample::OBSERVABLES.map { |observable| run.summary[observable] }
    end
  end
end
