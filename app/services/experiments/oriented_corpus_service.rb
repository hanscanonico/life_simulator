# frozen_string_literal: true

module Experiments
  # The corpus-wide headline of OrientedArmsService: one row per experiment, each the total
  # of its arms, and a total over every finished founding run the lab holds — flagged,
  # emerged, replicator worlds and held, the counts a relock of the census would be argued
  # from. A run paid for its tasks is in none of them: it is never pooled with the
  # fitness-free runs (DESIGN.md §1.4). Each experiment is reduced to its total before the next is read, so no more than
  # one experiment's readings are held at a time. Three queries per experiment.
  class OrientedCorpusService
    include Callable

    def call
      OrientedArmsService::Report.new(arms: Experiment.order(:id).map { |experiment| row_of(experiment) })
    end

    private

    def row_of(experiment)
      OrientedArmsService.call(experiment: experiment, fitness_free: true).total.with(label: experiment.slug)
    end
  end
end
