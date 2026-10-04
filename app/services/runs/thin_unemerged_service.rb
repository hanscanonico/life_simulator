# frozen_string_literal: true

module Runs
  # Deletes the intermediate stored worlds of the founding runs that never crossed, the
  # retention the user approved on 2026-10-03 (`docs/design_record.md`, issue #268): such a
  # run keeps its first and last world and every reading, and loses the worlds between.
  #
  # A world between goes only once every instrument that has read anything in its
  # experiment, and `oriented_census/1` always, holds its static reading of it. An unread
  # world stays, so a run's Runs::OrientedSummary — readings and unread count alike — and
  # every reading taken off it come out the same after thinning as before.
  #
  # It works run by run and stops after `max_runs` thinned runs or `time_limit` seconds,
  # whichever comes first; a thinned run has nothing left to delete, so the next call
  # resumes where this one stopped. With `dry_run` it counts and deletes nothing.
  class ThinUnemergedService
    include Callable

    # Slugs of the experiments whose pre-registration reads the intermediate worlds of
    # founding runs that never crossed. None does (design record, 2026-10-03); a sweep
    # that will is named here before its runs finish.
    EXCLUDED_EXPERIMENTS = [].freeze

    REQUIRED_INSTRUMENT = Lab::DescendantReading::INSTRUMENT

    BYTES = "octet_length(snapshots.blob) + COALESCE(octet_length(snapshots.png), 0)"

    Tally = Data.define(:runs, :snapshots, :bytes) do
      def self.zero = new(runs: 0, snapshots: 0, bytes: 0)

      def +(other)
        Tally.new(runs: runs + other.runs, snapshots: snapshots + other.snapshots, bytes: bytes + other.bytes)
      end
    end

    # `by_experiment` is a Tally per experiment slug; `complete` is false where a limit
    # stopped the call before it had looked at every candidate run.
    Result = Data.define(:total, :by_experiment, :complete)

    # The founding runs that are terminal, never crossed under any rule, have no descendant
    # and sit outside EXCLUDED_EXPERIMENTS.
    def self.candidates
      Run.founding.terminal
         .where(emergence_epoch: nil, transition_epoch: nil, transition_epoch_relative: nil)
         .where.not(experiment_id: Experiment.where(slug: EXCLUDED_EXPERIMENTS).select(:id))
         .where("NOT EXISTS (SELECT 1 FROM runs descendants WHERE descendants.parent_run_id = runs.id)")
    end

    def initialize(dry_run: true, max_runs: nil, time_limit: nil)
      @dry_run = dry_run
      @max_runs = max_runs
      @time_limit = time_limit
    end

    def call
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      by_experiment = Hash.new(Tally.zero)
      complete = true

      self.class.candidates.select(:id, :experiment_id).find_each do |run|
        if spent?(by_experiment)
          complete = false
          break
        end

        tally = thin(run)
        by_experiment[slugs.fetch(run.experiment_id)] += tally if tally
      end

      Result.new(total: by_experiment.values.reduce(Tally.zero, :+), by_experiment: by_experiment.sort.to_h,
                 complete: complete)
    end

    # The worlds of `run` thinning would delete: neither its first nor its last restorable
    # world, and read statically by every instrument in `instruments`.
    def self.intermediate_worlds(run, instruments)
      worlds = Snapshot.restorable.where(run_id: run.id)
      ends = worlds.pick(Arel.sql("MIN(epoch)"), Arel.sql("MAX(epoch)"))
      return Snapshot.none if ends.nil? || ends.first.nil?

      instruments.reduce(worlds.where.not(epoch: ends)) do |scope, instrument|
        scope.where("NOT (#{OrientedSummariesService::UNREAD})", instrument: instrument)
      end
    end

    private

    def thin(run)
      rows = self.class.intermediate_worlds(run, instruments(run.experiment_id)).pluck(:id, Arel.sql(BYTES))
      return if rows.empty?
      return Tally.new(runs: 1, snapshots: rows.size, bytes: rows.sum(&:last)) if @dry_run

      delete(run, rows)
    end

    # The delete asks the whole selection again in the same statement, so a run requeued,
    # backfilled with a crossing or given a descendant since it was read loses nothing.
    def delete(run, rows)
      deleted = Snapshot.where(id: rows.map(&:first), run_id: self.class.candidates.where(id: run.id).select(:id))
                        .delete_all
      return if deleted.zero?

      Tally.new(runs: 1, snapshots: deleted, bytes: rows.sum(&:last))
    end

    def spent?(by_experiment)
      thinned = by_experiment.values.sum(&:runs)
      return false if thinned.zero?

      (@max_runs && thinned >= @max_runs) ||
        (@time_limit && Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started >= @time_limit)
    end

    def instruments(experiment_id)
      @instruments ||= {}
      @instruments[experiment_id] ||=
        (SnapshotReading.joins(:run).where(runs: { experiment_id: experiment_id }).distinct.pluck(:instrument) |
          [REQUIRED_INSTRUMENT]).sort
    end

    def slugs = @slugs ||= Experiment.pluck(:id, :slug).to_h
  end
end
