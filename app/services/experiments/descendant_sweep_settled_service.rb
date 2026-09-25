# frozen_string_literal: true

module Experiments
  # Whether a descendant sweep's reading is final (`docs/design_record.md`, 2026-09-25):
  # no parent can still qualify — every candidate is terminal, and every finished one that
  # kept its world has been read — and every child of every qualifying parent, one per
  # treatment and seed, has ended. Anything printed before that is interim.
  class DescendantSweepSettledService
    include Callable

    def initialize(experiment)
      @experiment = experiment
    end

    def call
      pool = DescendantParentsService.call(@experiment)
      return false if pool.qualifying.empty? || pool.candidates.any? { |run| !run.terminal? }
      return false if pool.skipped.key?(:no_reading)

      pool.qualifying.all? { |parent| settled?(parent) }
    end

    private

    def settled?(parent)
      statuses = children.fetch([parent.id, parent.epochs], [])
      statuses.size == expected_children && statuses.all? { |status| Run::TERMINAL_STATUSES.include?(status) }
    end

    def children
      @children ||= @experiment.runs.where.not(parent_run_id: nil).pluck(:parent_run_id, :parent_epoch, :status)
                               .group_by { |parent_id, epoch, _| [parent_id, epoch] }
                               .transform_values { |rows| rows.map(&:last) }
    end

    # One child per point of the grid and seed: the grid's lists multiply, a bundle counting
    # as one point.
    def expected_children
      @experiment.param_grid.values.map { |values| Array.wrap(values).size }.reduce(1, :*) * @experiment.seeds.size
    end
  end
end
