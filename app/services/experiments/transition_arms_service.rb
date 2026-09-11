# frozen_string_literal: true

module Experiments
  # The transition detector against the replicator census, arm by arm: of the runs of an
  # arm that have been sampled at all, how many the detector flagged, how many ever held a
  # replicator, how many both, and how many only one of the two. `transition_epoch` fires
  # on `compress_ratio` alone, so a claim about emergence has to hold on both observables
  # (DESIGN.md §1.2), and this is the block the sweep page publishes.
  #
  # Both counts come off indexed columns — `runs.transition_epoch` and the census index
  # over `samples` — so the block costs a fixed handful of queries whatever the sweep
  # holds. Reading every sample into Ruby for it costs a second at the programme's scale
  # (100 runs of 20 000 epochs sampled every 10 is ~200 000 rows), which is why the page
  # does not. TransitionReportService reads them for its per-run columns and counts its
  # own arms off those rows, over terminal runs only; this block counts every sampled run,
  # so mid-sweep the two disagree by the runs still going.
  #
  # It reads stored rows and changes nothing — not the detector, not a metric, not a run.
  class TransitionArmsService
    include Callable

    COLUMNS = %w[arm n flagged replicators replicators_wide both either_but_not_both].freeze

    # The window the corpus pass re-reads a stored world at, beside the top_k 16 the run's
    # own metrics are locked to (DESIGN.md §1.2). Nothing here moves that lock.
    WIDE_TOP_K = 64

    # A run replicated if any reading of its census is a number greater than zero, which is
    # the verdict `peak_replicator_count.to_f.positive?` reaches in TransitionReportService
    # over every numeric reading. Numbers sort above strings and above json null in jsonb,
    # so a missing count is no replicator here — and so is a count stored as a string,
    # whatever its digits say, which is the one reading where the two part.
    # `index_samples_on_run_id_replicated` carries exactly the rows this predicate passes,
    # and has to keep matching it.
    REPLICATED = "values -> 'replicator_count' > '0'::jsonb"

    Arm = Data.define(:label, :runs, :flagged, :replicated, :both, :replicated_wide) do
      def flagged_only = flagged - both

      def replicated_only = replicated - both

      def either_but_not_both = flagged_only + replicated_only

      def cells = [label, runs, flagged, replicated, replicated_wide, both, either_but_not_both]
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call = sampled_runs.group_by { |run| arm_label(run) }.map { |label, runs| arm(label, runs) }

    private

    def arm(label, runs)
      Arm.new(label: label, runs: runs.size, flagged: runs.count { |run| flagged?(run) },
              replicated: runs.count { |run| replicated?(run) },
              both: runs.count { |run| flagged?(run) && replicated?(run) },
              replicated_wide: replicated_wide(runs))
    end

    def flagged?(run) = run.transition_epoch.present?

    def replicated?(run) = replicated_run_ids.include?(run.id)

    # No corpus pass has read this arm at the wide window, so it has no count either way:
    # nothing rather than a zero, which would read as a measured negative.
    def replicated_wide(runs)
      measured = runs.select { |run| wide_peaks.key?(run.id) }

      measured.count { |run| wide_peaks[run.id].to_i.positive? } if measured.any?
    end

    def wide_peaks
      @wide_peaks ||= Rescore.where(run_id: @experiment.runs.select(:id), top_k: WIDE_TOP_K)
                             .group(:run_id).maximum(:replicator_count)
    end

    # A run nothing has been sampled from yet is no row: the block is a reading of stored
    # samples, not of the queue.
    def sampled_runs
      @sampled_runs ||= @experiment.runs.where(id: sampled_run_ids.to_a).order(:id)
                                   .select(:id, :params, :transition_epoch).to_a
    end

    def sampled_run_ids = @sampled_run_ids ||= run_ids_of(Sample.all)

    def replicated_run_ids = @replicated_run_ids ||= run_ids_of(Sample.where(REPLICATED))

    def run_ids_of(samples)
      samples.where(run_id: @experiment.runs.select(:id)).distinct.pluck(:run_id).to_set
    end

    def arm_label(run)
      labels = axes.filter_map { |axis| axis.label_of_run(run.params) }

      labels.empty? ? @experiment.slug : labels.join(" ")
    end

    def axes = @axes ||= Axis.sweep(@experiment.param_grid)
  end
end
