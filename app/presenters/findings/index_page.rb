# frozen_string_literal: true

module Findings
  # The findings log: every published claim, newest first, with the sweep it rests on and
  # how far that sweep has got, so a reader can see whether the claim is still moving.
  class IndexPage
    Row = Data.define(:finding, :experiment, :runs_done, :transitioned) do
      def experiment? = experiment.present?

      def runs_total = experiment.runs_count

      def transition_rate = Experiments::TransitionRate.new(transitioned: transitioned, finished: runs_done)
    end

    def self.build = new

    def rows
      @rows ||= findings.map do |finding|
        experiment = experiments[finding.experiment_slug]

        Row.new(finding: finding, experiment: experiment,
                runs_done: finished_counts[experiment&.id].to_i,
                transitioned: transitioned_counts[experiment&.id].to_i)
      end
    end

    def any? = rows.present?

    private

    def findings = @findings ||= Registry.all

    # An experiment named by a finding may not exist yet (the sweep is queued by hand),
    # and that must not take the page down.
    def experiments
      @experiments ||= Experiment.where(slug: findings.map(&:experiment_slug)).index_by(&:slug)
    end

    def finished_counts
      @finished_counts ||= Run.where(experiment_id: experiment_ids, status: "finished").group(:experiment_id).count
    end

    def transitioned_counts
      @transitioned_counts ||= Run.where(experiment_id: experiment_ids, status: "finished")
                                  .where.not(transition_epoch: nil).group(:experiment_id).count
    end

    def experiment_ids = experiments.values.map(&:id)
  end
end
