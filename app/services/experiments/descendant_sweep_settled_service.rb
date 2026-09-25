# frozen_string_literal: true

module Experiments
  # Whether a descendant sweep's reading is final (`docs/design_record.md`, 2026-09-25):
  # no parent can still qualify — every candidate is terminal, and every finished one that
  # kept its world has been read — and every child of every qualifying parent, one per
  # treatment and seed, has finished: a failed child's samples stop short of its budget,
  # so it holds the reading back until it is re-run. Anything printed before that is
  # interim.
  #
  # The pool's runs belong to another experiment, and its worlds and readings are written
  # without touching them, so the answer is held under a version of every row it reads:
  # the rule and grid, this sweep's children, and the parent sweep's runs, stored worlds
  # and readings.
  class DescendantSweepSettledService
    include Callable

    # The answer is the code's as much as the rows': these are the files that take it.
    # Digested once per boot.
    VERSION = Digest::SHA256.hexdigest(
      %w[app/services/experiments/descendant_sweep_settled_service.rb
         app/services/experiments/descendant_parents_service.rb app/models/lab/canonical_params.rb
         app/models/run.rb app/models/snapshot.rb]
        .map { |path| Rails.root.join(path).binread }.join
    )

    def initialize(experiment)
      @experiment = experiment
    end

    def call
      Rails.cache.fetch(["experiments/descendant_sweep_settled", VERSION, @experiment.id, inputs_version]) { settled? }
    end

    private

    def inputs_version
      source = Experiment.find_by(slug: @experiment.parents.fetch("experiment"))
      pool = source && RowsVersion.of(source.runs, Snapshot, SnapshotReading)

      Digest::SHA256.hexdigest([@experiment.parents, @experiment.param_grid, @experiment.seeds, children, source&.id,
                                pool].to_json)
    end

    def settled?
      pool = DescendantParentsService.call(@experiment)
      return false if pool.qualifying.empty? || pool.candidates.any? { |run| !run.terminal? }
      return false if pool.skipped.key?(:no_reading)

      pool.qualifying.all? { |parent| children_finished?(parent) }
    end

    def children_finished?(parent)
      statuses = children.fetch([parent.id, parent.epochs], [])
      statuses.size == expected_children && statuses.all?("finished")
    end

    def children
      @children ||= @experiment.runs.where.not(parent_run_id: nil).order(:id)
                               .pluck(:parent_run_id, :parent_epoch, :status)
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
