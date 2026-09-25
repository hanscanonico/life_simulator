# frozen_string_literal: true

require "csv"

module Experiments
  # The per-run rows behind OrientedArmsService as CSV lines: each finished founding run's
  # detector and emergence epochs beside its Runs::OrientedSummary, and how many of its
  # readings came from stored worlds and how many from live samples. A run nothing has read
  # is `measured` false with its census cells blank, never zero; the epochs are only as
  # fine as the readings, stored worlds about every 1000 epochs apart.
  class OrientedCsvService
    include Callable
    include NamesRunArms

    COLUMNS = %w[run_id seed arm transition_epoch emergence_epoch measured stored_readings live_readings
                 terminal_share peak_share peak_epoch first_replicator_epoch held].freeze

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Enumerator.new do |lines|
        lines << CSV.generate_line(COLUMNS)
        runs.each { |run| lines << CSV.generate_line(row(run, summaries.fetch(run.id))) }
      end
    end

    private

    def row(run, summary)
      [run.id, run.seed, arm_label(run), run.transition_epoch, run.emergence_epoch, summary.measured?,
       summary.stored_count, summary.live_count, summary.terminal_share, summary.peak_share, summary.peak_epoch,
       summary.first_replicator_epoch, summary.held]
    end

    def summaries = @summaries ||= Runs::OrientedSummariesService.call(runs: runs)

    def runs
      @runs ||= experiment.runs.founding.where(status: "finished").order(:id)
                          .select(:id, :seed, :params, :epochs, :transition_epoch, :emergence_epoch).to_a
    end

    attr_reader :experiment
  end
end
