# frozen_string_literal: true

module Experiments
  # The transition detector against the replicator census, arm by arm: of the runs of an
  # arm that have been sampled at all, how many the detector flagged, how many ever held a
  # replicator, how many both, and how many only one of the two. `transition_epoch` fires
  # on `compress_ratio` alone, so a claim about emergence has to hold on both observables
  # (DESIGN.md §1.2), and this is the block the sweep page publishes.
  #
  # Both counts come off indexed columns — `runs.transition_epoch` and the census index
  # over `samples` — so the block costs three queries whatever the sweep holds. Reading
  # every sample into Ruby for it costs a second at the programme's scale (100 runs of
  # 20 000 epochs sampled every 10 is ~200 000 rows), which is why the page does not:
  # TransitionReportService, which has to read them for its per-run columns, reports the
  # same block under its rows rather than counting a second time.
  #
  # It reads stored rows and changes nothing — not the detector, not a metric, not a run.
  class TransitionArmsService
    include Callable

    COLUMNS = %w[arm n flagged replicators both either_but_not_both].freeze

    # `index_samples_on_run_id_replicated` carries exactly the rows this predicate passes,
    # and has to keep matching it. Numbers sort above strings in jsonb, so a non-numeric
    # count never passes the comparison.
    REPLICATED = "values -> 'replicator_count' > '0'::jsonb"

    Arm = Data.define(:label, :runs, :flagged, :replicated, :both) do
      def either_but_not_both = flagged + replicated - (2 * both)

      def cells = [label, runs, flagged, replicated, both, either_but_not_both]
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call = sampled_runs.group_by { |run| arm_label(run) }.map { |label, runs| arm(label, runs) }

    private

    def arm(label, runs)
      Arm.new(label: label, runs: runs.size, flagged: runs.count { |run| flagged?(run) },
              replicated: runs.count { |run| replicated?(run) },
              both: runs.count { |run| flagged?(run) && replicated?(run) })
    end

    def flagged?(run) = run.transition_epoch.present?

    def replicated?(run) = replicated_run_ids.include?(run.id)

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
