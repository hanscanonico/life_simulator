# frozen_string_literal: true

module Runs
  # Puts the failed runs of an experiment back in the pending queue, as if they had never
  # been claimed: the fix for a run lost to a runner bug rather than to its parameters.
  # `epochs_done` goes back to 0, so the runner starts the run from epoch 0 instead of
  # restoring its latest snapshot; determinism from (params, seed) means the rerun rewrites
  # the same samples and snapshots, which is why the old ones are left in place.
  class RequeueFailedService
    include Callable

    REQUEUED_ATTRIBUTES = { status: "pending", epochs_done: 0, epochs_done_at: nil,
                            runner_id: nil, claimed_at: nil, heartbeat_at: nil,
                            started_at: nil, finished_at: nil, error: nil, summary: {},
                            transition_epoch: nil }.freeze

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Run.transaction do
        requeued = @experiment.runs.failed.to_a
        requeued.each { |run| run.update!(REQUEUED_ATTRIBUTES) }
        @experiment.queued! if requeued.any? && @experiment.finished?
        requeued.size
      end
    end
  end
end
