# frozen_string_literal: true

module Experiments
  # Expands an experiment's `param_grid × seeds` into one queued Run per combination.
  # The cartesian product is taken in grid insertion order, seeds innermost, so the run
  # order of a sweep is reproducible. A grid value that is a Hash contributes all of its
  # keys at once, which is how paired parameters (a square world's width and height) stay
  # paired instead of multiplying against each other.
  class SweepBuilderService
    include Callable

    def initialize(experiment)
      @experiment = experiment
    end

    def call
      Experiment.transaction do
        param_sets.each do |params|
          @experiment.seeds.each { |seed| build_run(params, seed) }
        end
        @experiment.queued!
      end
      @experiment
    end

    private

    def build_run(params, seed)
      return if existing_keys.include?(identity(params, seed))

      @experiment.runs.create!(params: params, seed: seed, epochs: @experiment.epochs,
                               priority: @experiment.priority)
      existing_keys << identity(params, seed)
    end

    def existing_keys
      @existing_keys ||= @experiment.runs.pluck(:params, :seed)
                                    .to_set { |params, seed| identity(params, seed) }
    end

    # Two runs are the same run when they resolve to the same parameters, not when their
    # `params` columns look alike: a parameter left out of a run's params takes the engine
    # default (Lab::Schema::NON_RUN_PARAMS, and any parameter the engine grew after the run
    # was built), and JSON has a single number type, so a hand-written 0 and a grid's 0.0
    # are one value. Without both, rebuilding a sweep duplicates the runs it already has.
    def identity(params, seed)
      resolved = Lab::Schema.defaults.merge(params)
                            .transform_values { |value| value.is_a?(Numeric) ? value.to_f : value }
      [resolved, seed]
    end

    def param_sets
      axes = @experiment.param_grid.map { |name, values| values.map { |value| axis_params(name, value) } }
      return [Lab::Schema.run_defaults.dup] if axes.empty?

      head, *tail = axes
      head.product(*tail).map { |parts| parts.reduce(Lab::Schema.run_defaults.dup, :merge) }
    end

    def axis_params(name, value)
      value.is_a?(Hash) ? value : { name => value }
    end
  end
end
