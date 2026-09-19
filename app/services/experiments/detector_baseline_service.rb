# frozen_string_literal: true

require "csv"

module Experiments
  # How close a freshly initialised soup already sits to the detector's constant
  # threshold, arm by arm. The transition detector fires on `compress_ratio` below a fixed
  # 0.6 (DESIGN.md §1.2), so an arm whose initial condition compresses further — a large
  # `max_tape_len` leaves more room for the compressor — starts with less of a gap to
  # cross, and crosses on the substrate rather than on anything that replicated. This
  # reads, per arm, the `compress_ratio` of the first 500 epochs against that constant,
  # when the first crossing came, and how often it came early.
  #
  # It reads stored samples and changes nothing: whether the detector should take a
  # per-run baseline instead of a constant is a decision for whoever reads these numbers.
  class DetectorBaselineService
    include Callable

    THRESHOLD = Lab::Schema.transition.fetch("threshold")
    BASELINE_EPOCHS = 500
    EARLY_CROSSING_EPOCHS = 1_000

    COLUMNS = %w[arm n max_tape_len mean_compress_ratio min_compress_ratio mean_first_crossing_epoch
                 early_crossing_share].freeze

    Row = Data.define(:max_tape_len, :baseline_ratios, :first_crossing_epoch) do
      def baseline_mean
        baseline_ratios.sum / baseline_ratios.size unless baseline_ratios.empty?
      end

      def early_crossing? = first_crossing_epoch.present? && first_crossing_epoch <= EARLY_CROSSING_EPOCHS
    end

    # The arm mean weighs each run once, not each sample: an arm whose runs were sampled
    # at different cadences is still a mean over its seeds.
    Arm = Data.define(:label, :rows) do
      def runs = rows.size

      def max_tape_len = rows.filter_map(&:max_tape_len).uniq.sort.join("/").presence

      def mean_compress_ratio
        means = rows.filter_map(&:baseline_mean)
        means.sum / means.size unless means.empty?
      end

      def min_compress_ratio = rows.flat_map(&:baseline_ratios).min

      def mean_first_crossing_epoch
        epochs = rows.filter_map(&:first_crossing_epoch)
        epochs.sum.to_f / epochs.size unless epochs.empty?
      end

      def early_crossing_share = rows.count(&:early_crossing?).to_f / runs

      def cells
        [label, runs, max_tape_len, mean_compress_ratio, min_compress_ratio, mean_first_crossing_epoch,
         early_crossing_share]
      end
    end

    Report = Data.define(:arms) do
      def runs = arms.sum(&:runs)

      def to_text = [table(COLUMNS, arms.map(&:cells)), "\n", summary].join

      def to_csv
        CSV.generate do |csv|
          csv << COLUMNS
          arms.each { |arm| csv << arm.cells }
        end
      end

      private

      def summary
        "#{runs} terminal runs read, mean and min over epochs <= #{BASELINE_EPOCHS} " \
          "against the constant threshold #{THRESHOLD}\n" \
          "early_crossing_share is the share of the arm's runs first crossing it " \
          "by epoch #{EARLY_CROSSING_EPOCHS}\n"
      end

      def table(columns, cells)
        lines = [columns, *cells.map { |row| row.map { |cell| format_cell(cell) } }]
        widths = lines.transpose.map { |column| column.map(&:length).max }

        lines.map { |line| "#{line.each_with_index.map { |cell, index| cell.rjust(widths[index]) }.join('  ')}\n" }
             .join
      end

      def format_cell(cell)
        return "—" if cell.nil?
        return Charts.format_value(cell) if cell.is_a?(Float)

        cell.to_s
      end
    end

    def initialize(experiment: nil)
      @experiment = experiment
    end

    def call = Report.new(arms: arms)

    private

    def arms
      sampled_runs.group_by { |run, _| arm_label(run) }
                  .map { |label, pairs| Arm.new(label: label, rows: pairs.map { |run, samples| row(run, samples) }) }
    end

    def row(run, samples)
      Row.new(max_tape_len: run.params["max_tape_len"], baseline_ratios: baseline_ratios(samples),
              first_crossing_epoch: first_crossing_epoch(samples))
    end

    # The window is the sample's own epoch, not its rank among the samples: a run sampled
    # every 100 epochs and one sampled every 10 must cover the same stretch of world time.
    def baseline_ratios(samples)
      samples.select { |epoch, _| epoch <= BASELINE_EPOCHS }.filter_map { |_, ratio| ratio }
    end

    def first_crossing_epoch(samples)
      samples.find { |_, ratio| ratio.present? && ratio < THRESHOLD }&.first
    end

    # A run nothing has been sampled from yet is no row, and a run still going is left out
    # the way the sibling reports leave it out: its samples are a partial reading.
    def sampled_runs
      runs = scope.to_a
      by_run = Sample.where(run: runs).order(:epoch)
                     .pluck(:run_id, :epoch, Arel.sql("(values ->> 'compress_ratio')::float"))
                     .group_by(&:first)

      runs.filter_map do |run|
        samples = by_run[run.id]
        [run, samples.map { |(_, epoch, ratio)| [epoch, ratio] }] if samples
      end
    end

    def scope
      runs = Run.terminal.order(:id).includes(:experiment)

      @experiment ? runs.where(experiment: @experiment) : runs
    end

    def arm_label(run)
      labels = axes_of(run.experiment).filter_map { |axis| axis.label_of_run(run.params) }
      slug = run.experiment&.slug

      return slug.to_s if labels.empty?

      @experiment ? labels.join(" ") : "#{slug} #{labels.join(' ')}"
    end

    def axes_of(experiment)
      return [] if experiment.nil?

      (@axes_of ||= {})[experiment.id] ||= Axis.sweep(experiment.param_grid)
    end
  end
end
