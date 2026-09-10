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
      return if existing_keys.include?([params, seed])

      @experiment.runs.create!(params: params, seed: seed, epochs: @experiment.epochs,
                               priority: @experiment.priority)
      existing_keys << [params, seed]
    end

    def existing_keys
      @existing_keys ||= @experiment.runs.pluck(:params, :seed).to_set
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
