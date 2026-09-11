# frozen_string_literal: true

module Experiments
  # What an experiment's arms cost in compute: for every run that has accumulated compute
  # seconds, the epochs it did per second of compute, summarised per arm, and the compute
  # hours the arm has burned. The rate is the one figure that makes two arms comparable
  # when the sweep changes the work per epoch (world size, radius, max_steps), and
  # `runs.compute_seconds` is the only record of it that survives a resume — the runner's
  # `wall_s` covers one claim and its log rotates.
  #
  # It reads stored rows and changes nothing.
  class CostReportService
    include Callable

    COLUMNS = %w[arm n mean_epochs_per_compute_s min max compute_hours].freeze

    Arm = Data.define(:label, :rates, :seconds) do
      def runs = rates.size

      def mean = rates.sum / rates.size

      def compute_hours = seconds / 3600

      def cells = [label, runs, mean, rates.min, rates.max, compute_hours]
    end

    Report = Data.define(:arms) do
      def compute_hours = arms.sum(&:compute_hours)

      def runs = arms.sum(&:runs)

      def to_text = [table(COLUMNS, arms.map(&:cells)), "\n", summary].join

      private

      def summary
        "#{runs} runs with compute recorded, #{Charts.format_value(compute_hours)} compute hours in total\n"
      end

      def table(columns, cells)
        lines = [columns, *cells.map { |row| row.map { |cell| format_cell(cell) } }]
        widths = lines.transpose.map { |column| column.map(&:length).max }

        lines.map { |line| "#{line.each_with_index.map { |cell, index| cell.rjust(widths[index]) }.join('  ')}\n" }
             .join
      end

      def format_cell(cell) = cell.is_a?(Float) ? Charts.format_value(cell) : cell.to_s
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call = Report.new(arms: arms)

    private

    def arms
      measured_runs.group_by { |run| arm_label(run) }.map do |label, runs|
        Arm.new(label: label, rates: runs.map { |run| rate_of(run) }, seconds: runs.sum(&:compute_seconds))
      end
    end

    def rate_of(run) = run.epochs_done / run.compute_seconds

    # A run nothing has been charged to yet is no row: a pending run, and a run a runner
    # that predates `interval_seconds` worked on, have no cost to report.
    def measured_runs
      @measured_runs ||= @experiment.runs.where("compute_seconds > 0").order(:id)
                                    .select(:id, :params, :epochs_done, :compute_seconds).to_a
    end

    def arm_label(run)
      labels = axes.filter_map { |axis| axis.label_of_run(run.params) }

      labels.empty? ? @experiment.slug : labels.join(" ")
    end

    def axes = @axes ||= Axis.sweep(@experiment.param_grid)
  end
end
