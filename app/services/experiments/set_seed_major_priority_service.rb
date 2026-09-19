# frozen_string_literal: true

module Experiments
  # Orders an experiment's queue seed-major rather than flat: every unfinished run gets
  # `base - seed`, so `Runs::ClaimService`'s `priority desc, id asc` serves seed 0 of every
  # arm before seed 1 of any arm and a multi-arm sweep widens before it deepens. The
  # experiment itself keeps `base`, the priority the runs it has yet to build are seeded at.
  # The runs move in one UPDATE: a sweep is hundreds of runs, and one row at a time is one
  # statement each.
  class SetSeedMajorPriorityService
    include Callable

    def initialize(experiment:, base:)
      @experiment = experiment
      @base = base
    end

    def call
      Experiment.transaction do
        @experiment.update!(priority: @base)
        moved = unfinished.update_all(seed_major_priority)
        band(moved)
      end
    end

    private

    def unfinished = @experiment.runs.where.not(status: Run::TERMINAL_STATUSES)

    def seed_major_priority
      Arel.sql(ActiveRecord::Base.sanitize_sql_array(["priority = ? - seed", @base]))
    end

    def band(moved)
      return PriorityBand.empty if moved.zero?

      lowest, highest = unfinished.pick(Arel.sql("MIN(priority), MAX(priority)"))
      PriorityBand.new(moved: moved, lowest: lowest, highest: highest)
    end
  end
end
