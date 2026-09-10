# frozen_string_literal: true

module Runs
  # Snapshots dominate the lab database: a 128×128 soup world is ~1 MB and every run posts
  # one every `snapshot_every` epochs. Once a run is terminal nobody resumes from them any
  # more, so a terminal run keeps a thinned-out gallery: its first and last worlds, one every
  # `keep_every` epochs, and the one nearest the transition epoch.
  class PruneSnapshotsService
    include Callable

    # Ten snapshots in, one kept: 20 of the 200 a default 20 000-epoch run posts.
    KEEP_FACTOR = 10
    # An upper bound on what a run of `epochs` epochs keeps: first, last, transition and the
    # multiples of `keep_every`. Used as a cheap SQL prefilter, never as the keep set itself.
    KEEP_SLACK = 3

    # Terminal runs finished since `since` that still carry more snapshots than they could
    # possibly keep. Runs still pending, claimed or running are excluded: the runner resumes
    # from the latest snapshot, so theirs are load-bearing.
    def self.prunable(since:)
      Run.terminal
         .where(finished_at: since..)
         .joins(:snapshots)
         .group("runs.id")
         .having("COUNT(snapshots.id) > (runs.epochs / #{default_keep_every}) + #{KEEP_SLACK}")
    end

    def self.default_keep_every = KEEP_FACTOR * Lab::Schema.defaults.fetch("snapshot_every")

    def initialize(run:, keep_every: nil)
      @run = run
      @keep_every = keep_every || run_keep_every
    end

    def call
      return 0 unless @run.terminal?
      return 0 if epochs.empty?

      @run.snapshots.where.not(epoch: kept_epochs).delete_all
    end

    def kept_epochs
      kept = Set[epochs.first, epochs.last]
      kept.merge(epochs.select { |epoch| (epoch % @keep_every).zero? })
      kept << nearest_to_transition if @run.transition_epoch
      kept.sort
    end

    private

    # `snapshot_every` is normally the runner's business (Lab::Schema::NON_RUN_PARAMS), but a
    # sweep can put it on the grid, and then the run posts at its own cadence.
    def run_keep_every
      every = @run.params["snapshot_every"]
      every ? KEEP_FACTOR * every : self.class.default_keep_every
    end

    def epochs = @epochs ||= @run.snapshots.order(:epoch).pluck(:epoch)

    def nearest_to_transition
      epochs.min_by { |epoch| [(epoch - @run.transition_epoch).abs, epoch] }
    end
  end
end
