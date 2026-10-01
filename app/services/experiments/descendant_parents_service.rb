# frozen_string_literal: true

module Experiments
  # Reads a descendant sweep's parent rule (`experiment.parents`) against the runs it names:
  # which candidates qualify, and why each of the others does not yet. Both the builder,
  # which starts children from the qualifying ones, and the reading, which is interim until
  # the pool is settled, read the rule through here. It changes nothing.
  class DescendantParentsService
    include Callable

    Pool = Data.define(:candidates, :qualifying, :skipped)

    def initialize(experiment)
      @rule = experiment.parents
    end

    def call
      skipped = Hash.new { |hash, reason| hash[reason] = [] }
      qualifying = candidates.select do |run|
        reason = skip_reason(run)
        skipped[reason] << run.id if reason
        reason.nil?
      end

      Pool.new(candidates: candidates, qualifying: qualifying, skipped: skipped.to_h)
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
      return :no_terminal_world unless terminal_worlds.include?(run.id)

      share = terminal_shares[run.id]
      return :no_reading if share.nil?

      :below_share if share < @rule.fetch("min_share")
    end

    # The candidates that kept a world at their last epoch, in one statement: the reading
    # asks this of the whole pool on every page request.
    def terminal_worlds
      @terminal_worlds ||= Snapshot.restorable.joins(:run).where(run_id: candidates.map(&:id))
                                   .where("snapshots.epoch = runs.epochs").distinct.pluck(:run_id).to_set
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
  end
end
