# frozen_string_literal: true

module Findings
  # The findings log: every published claim, newest first, with the sweep it rests on and
  # how far that sweep has got, so a reader can see whether the claim is still moving.
  class IndexPage
    # The rate is read over founding runs alone, as Experiments::IndexPage reads it.
    Row = Data.define(:finding, :experiment, :related_experiments, :runs_done, :founding_done, :transitioned) do
      def experiment? = experiment.present?

      def related? = related_experiments.present?

      def runs_total = experiment.runs_count

      def transition_rate = Experiments::TransitionRate.new(transitioned: transitioned, finished: founding_done)
    end

    def self.build = new

    def rows
      @rows ||= findings.map do |finding|
        experiment = experiments[finding.experiment_slug]

        Row.new(finding: finding, experiment: experiment,
                related_experiments: experiments.values_at(*finding.related_experiment_slugs).compact,
                runs_done: finished_counts[experiment&.id].to_i,
                founding_done: founding_finished_counts[experiment&.id].to_i,
                transitioned: transitioned_counts[experiment&.id].to_i)
      end
    end

    def any? = rows.present?

    def programme_status = @programme_status ||= Programme::Status.build

    # The denominator of a finding that names no sweep: the same set of runs its own
    # page surveys, so the row and the write-up never state different totals.
    def transitioned_runs_count = @transitioned_runs_count ||= Run.transitioned.count

    # The sweeps that set of runs came from, so the row links what the finding rests on
    # rather than the whole lab.
    def transitioned_sweeps
      @transitioned_sweeps ||= Experiment.where(id: Run.transitioned.select(:experiment_id)).order(:name).to_a
    end

    private

    def findings = @findings ||= Registry.all

    # An experiment named by a finding may not exist yet (the sweep is queued by hand),
    # and that must not take the page down.
    def experiments
      @experiments ||= Experiment.where(slug: findings.flat_map(&:experiment_slugs)).index_by(&:slug)
    end

    def finished_counts = @finished_counts ||= sum_by_experiment(finished_by_founding)

    def founding_finished_counts
      @founding_finished_counts ||= sum_by_experiment(finished_by_founding.select { |(_, founding), _| founding })
    end

    # One query for both counts: every finished run, keyed by experiment and by whether it
    # is a founding run.
    def finished_by_founding
      @finished_by_founding ||= Run.where(experiment_id: experiment_ids, status: "finished")
                                   .group(:experiment_id, Arel.sql("runs.parent_run_id IS NULL")).count
    end

    def sum_by_experiment(counts)
      counts.each_with_object(Hash.new(0)) { |((experiment_id, _), count), sums| sums[experiment_id] += count }
    end

    def transitioned_counts
      @transitioned_counts ||= Run.founding.where(experiment_id: experiment_ids, status: "finished")
                                  .where.not(transition_epoch: nil).group(:experiment_id).count
    end

    def experiment_ids = experiments.values.map(&:id)
  end
end
