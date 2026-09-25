# frozen_string_literal: true

module Experiments
  # The corpus-wide headline of OrientedArmsService: one row per experiment, each the total
  # of its arms, and a total over every finished founding run the lab holds — flagged,
  # emerged, replicator worlds and held, the counts a relock of the census would be argued
  # from. Three queries per experiment.
  class OrientedCorpusService
    include Callable

    def call
      OrientedArmsService::Report.new(arms: Experiment.order(:id).map { |experiment| row_of(experiment) })
    end

    private

    def row_of(experiment)
      OrientedArmsService::Arm.new(label: experiment.slug,
                                   rows: OrientedArmsService.call(experiment: experiment).total.rows)
    end
  end
end
