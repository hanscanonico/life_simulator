# frozen_string_literal: true

module Experiments
  # The sweep list: how far each experiment has got and how often it saw a transition.
  class IndexPage
    Row = Data.define(:experiment, :runs_done, :transitioned, :findings) do
      def runs_total = experiment.runs_count

      def transition_rate = TransitionRate.new(transitioned: transitioned, finished: runs_done)
    end

    Planned = Data.define(:slug, :name, :description)

    def self.build = new

    def rows
      @rows ||= experiments.map do |experiment|
        Row.new(experiment: experiment, runs_done: finished_counts[experiment.id].to_i,
                transitioned: transitioned_counts[experiment.id].to_i,
                findings: Findings::Registry.for_experiment(experiment.slug))
      end
    end

    def any? = rows.present?

    # The sweeps of the programme (Lab::SWEEPS) that no `rake lab:sweep` has turned into an
    # Experiment yet: the plan is public even before a run exists.
    def planned
      @planned ||= Lab::SWEEPS.filter_map do |key, definition|
        slug = Lab.slug_for(key)
        name = definition.fetch(:name)
        next if queued_slugs.include?(slug) || queued_names.include?(name.downcase)

        Planned.new(slug: slug, name: name, description: definition.fetch(:description))
      end
    end

    private

    def queued_slugs = @queued_slugs ||= experiments.to_set(&:slug)

    # A sweep built by hand can carry any slug, so its name is the second way to recognise
    # it: the plan must not advertise a sweep the lab is already running.
    def queued_names = @queued_names ||= experiments.to_set { |experiment| experiment.name.downcase }

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
