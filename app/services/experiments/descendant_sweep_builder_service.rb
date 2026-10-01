# frozen_string_literal: true

module Experiments
  # Builds a descendant sweep: every qualifying parent × every treatment of the grid × every
  # seed becomes one Run started from the parent's last stored world (Run.descend_from),
  # under the parent's params with the treatment merged over them.
  #
  # The experiment's `parents` names the rule: the experiment the parents come from, the
  # arms they must belong to (matched as `seeds_by_arm`'s list form matches, canonically),
  # and the reading of the terminal world that qualifies one — an instrument, a key and a
  # minimum, read by Experiments::DescendantParentsService. A candidate that is not
  # finished, kept no world at its last epoch, or has no such reading yet is skipped and
  # counted, so a later re-seed picks it up once it qualifies.
  #
  # Seeding is idempotent on (canonical params, seed, parent run, parent epoch), so a
  # re-seed only adds the children of parents that qualified since.
  class DescendantSweepBuilderService
    include Callable

    SKIP_REASONS = {
      unfinished: "not finished",
      no_terminal_world: "no stored world at the last epoch",
      no_reading: "no reading of the last world",
      below_share: "share below the minimum"
    }.freeze

    Report = Data.define(:parents, :created, :skipped) do
      def to_s
        skips = SKIP_REASONS.filter_map do |reason, label|
          ids = skipped.fetch(reason, [])
          "#{label}: #{ids.size} (runs #{ids.join(', ')})" if ids.any?
        end
        line = "#{parents.size} qualifying parents, #{created} children created"
        skips.any? ? "#{line}; skipped #{skips.join('; ')}" : line
      end
    end

    def initialize(experiment)
      @experiment = experiment
    end

    def call
      pool = DescendantParentsService.call(@experiment)
      created = 0

      Experiment.transaction do
        created = pool.qualifying.sum { |run| build_children(run) }
        @experiment.queued!
      end

      Report.new(parents: pool.qualifying, created: created, skipped: pool.skipped)
    end

    private

    def build_children(parent)
      treatments.sum do |treatment|
        params = parent.params.merge(treatment)
        @experiment.seeds.count { |seed| build_child(parent, params, seed) }
      end
    end

    def build_child(parent, params, seed)
      key = [Lab::CanonicalParams.for(params), seed, parent.id, parent.epochs]
      return false if existing_keys.include?(key)

      Run.descend_from(parent, params: params, seed: seed, budget: @experiment.epochs,
                               experiment: @experiment, epoch: parent.epochs)
      existing_keys << key
    end

    def existing_keys
      @existing_keys ||= @experiment.runs.pluck(:params, :seed, :parent_run_id, :parent_epoch)
                                    .to_set do |params, seed, parent_id, epoch|
        [Lab::CanonicalParams.for(params), seed, parent_id, epoch]
      end
    end

    # The grid's points, in grid order, as the parameters each merges over a parent: a
    # bundle contributes all of its keys, so the empty bundle changes nothing.
    def treatments
      @treatments ||= begin
        axes = @experiment.param_grid.map do |name, values|
          values.map { |value| value.is_a?(Hash) ? value : { name => value } }
        end
        head, *tail = axes
        head.nil? ? [{}] : head.product(*tail).map { |parts| parts.reduce({}, :merge) }
      end
    end
  end
end
