# frozen_string_literal: true

module Experiments
  # The sweep list: how far each experiment has got and how often it saw a transition.
  class IndexPage
    Row = Data.define(:experiment, :runs_done, :transitioned) do
      def runs_total = experiment.runs_count

      # Share of *finished* runs that reached a transition epoch: pending runs are not
      # evidence of anything either way.
      def transition_rate
        return nil if runs_done.zero?

        transitioned.fdiv(runs_done)
      end
    end

    Planned = Data.define(:slug, :name, :description)

    def self.build = new

    def rows
      @rows ||= experiments.map do |experiment|
        Row.new(experiment: experiment, runs_done: finished_counts[experiment.id].to_i,
                transitioned: transitioned_counts[experiment.id].to_i)
      end
    end

    def any? = rows.present?

    # The sweeps of the programme (Lab::SWEEPS) that no `rake lab:sweep` has turned into an
    # Experiment yet: the plan is public even before a run exists.
    def planned
      @planned ||= Lab::SWEEPS.filter_map do |key, definition|
        slug = key.tr("_", "-")
        next if queued_slugs.include?(slug)

        Planned.new(slug: slug, name: definition.fetch(:name), description: definition.fetch(:description))
      end
    end

    private

    def queued_slugs = @queued_slugs ||= experiments.to_set(&:slug)

    def experiments = @experiments ||= Experiment.order(:name).to_a

    def finished_counts
      @finished_counts ||= Run.where(status: "finished").group(:experiment_id).count
    end

    def transitioned_counts
      @transitioned_counts ||= Run.where(status: "finished").where.not(transition_epoch: nil)
                                  .group(:experiment_id).count
    end
  end
end
