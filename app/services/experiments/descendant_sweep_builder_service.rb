# frozen_string_literal: true

module Experiments
  # Builds a descendant sweep: every qualifying parent × every treatment of the grid × every
  # seed becomes one Run started from the parent's last stored world (Run.descend_from),
  # under the parent's params with the treatment merged over them.
  #
  # The experiment's `parents` names the rule: the experiment the parents come from, the
  # arms they must belong to (matched as `seeds_by_arm`'s list form matches, canonically),
  # and the reading of the terminal world that qualifies one — an instrument, a key and a
  # minimum. A candidate that is not finished, kept no world at its last epoch, or has no
  # such reading yet is skipped and counted, so a later re-seed picks it up once it
  # qualifies.
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
      @rule = experiment.parents
    end

    def call
      skipped = Hash.new { |hash, reason| hash[reason] = [] }
      created = 0
      parents = []

      Experiment.transaction do
        candidates.each do |run|
          reason = skip_reason(run)
          next skipped[reason] << run.id if reason

          parents << run
          created += build_children(run)
        end
        @experiment.queued!
      end

      Report.new(parents: parents, created: created, skipped: skipped.to_h)
    end

    private

    def candidates
      @candidates ||= begin
        source = Experiment.find_by(slug: @rule.fetch("experiment"))
        source.nil? ? [] : source.runs.founding.order(:id).select { |run| in_arms?(run.params) }
      end
    end

    def in_arms?(params)
      @rule.fetch("arms").any? do |arm|
        arm.all? { |name, value| Lab::CanonicalParams.same_value?(params[name], value) }
      end
    end

    def skip_reason(run)
      return :unfinished unless run.finished?
      return :no_terminal_world unless run.snapshots.restorable.exists?(epoch: run.epochs)

      share = terminal_shares[run.id]
      return :no_reading if share.nil?

      :below_share if share < @rule.fetch("min_share")
    end

    # The qualifying value of each candidate's reading at its last epoch, by run id.
    def terminal_shares
      @terminal_shares ||= begin
        value = Arel::Nodes::InfixOperation.new("->>", SnapshotReading.arel_table[:values],
                                                Arel::Nodes.build_quoted(@rule.fetch("share_key")))
        SnapshotReading.joins(:run).where(instrument: @rule.fetch("instrument"))
                       .where(run_id: candidates.map(&:id)).where("snapshot_readings.epoch = runs.epochs")
                       .pluck(:run_id, value).to_h { |run_id, share| [run_id, share&.to_f] }
      end
    end

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
