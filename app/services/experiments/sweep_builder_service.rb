# frozen_string_literal: true

module Experiments
  # Expands an experiment's `param_grid × seeds` into one queued Run per combination.
  # The cartesian product is taken in grid insertion order, seeds innermost, so the run
  # order of a sweep is reproducible. A grid value that is a Hash contributes all of its
  # keys at once, which is how paired parameters (a square world's width and height) stay
  # paired instead of multiplying against each other.
  #
  # An arm can run more seeds than the rest of its sweep, and `seeds_by_arm` names it in
  # one of two shapes. The one-parameter form, `{ name => { value => seeds } }`, gives every
  # grid point holding that value a list of its own. The list form,
  # `[{ "params" => { name => value, ... }, "seeds" => seeds }]`, names an arm by several
  # parameters at once — a bundle's keys and a crossed axis together — and a grid point is
  # that arm only where every one of them matches. The first arm a grid point matches gives
  # its seeds. jsonb hands the one-parameter form's values back as strings, so an arm is
  # recognised by the same canonical comparison a rake argument gets and never by `==`.
  #
  # Seeding is idempotent: a run is identified by (canonical params, seed), so re-running a
  # sweep whose grid gained an arm creates that arm's runs and nothing else. See
  # Lab::CanonicalParams for why the comparison cannot be a plain hash equality.
  class SweepBuilderService
    include Callable

    def initialize(experiment)
      @experiment = experiment
    end

    def call
      Experiment.transaction do
        param_sets.each do |params|
          seeds_for(params).each { |seed| build_run(params, seed) }
        end
        @experiment.queued!
      end
      @experiment
    end

    private

    def seeds_for(params)
      _, seeds = arm_seeds.find do |arm, _|
        arm.all? { |name, value| Lab::CanonicalParams.same_value?(params[name], value) }
      end

      seeds || @experiment.seeds
    end

    def arm_seeds
      @arm_seeds ||= if @experiment.seeds_by_arm.is_a?(Array)
                       @experiment.seeds_by_arm.map { |arm| arm.values_at("params", "seeds") }
                     else
                       @experiment.seeds_by_arm.flat_map do |name, seeds_by_value|
                         seeds_by_value.map { |value, seeds| [{ name => value }, seeds] }
                       end
                     end
    end

    def build_run(params, seed)
      key = [Lab::CanonicalParams.for(params), seed]
      return if existing_keys.include?(key)

      @experiment.runs.create!(params: params, seed: seed, epochs: @experiment.epochs,
                               priority: @experiment.priority)
      existing_keys << key
    end

    def existing_keys
      @existing_keys ||= @experiment.runs.pluck(:params, :seed)
                                    .to_set { |params, seed| [Lab::CanonicalParams.for(params), seed] }
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
