# frozen_string_literal: true

module Runs
  # Hands the most urgent pending run to a runner: highest priority first, oldest run
  # within a priority, so a control experiment queued today can jump ahead of a long
  # sweep. `FOR UPDATE SKIP LOCKED` is what makes two runners claiming at the same
  # instant get two different runs instead of the same one.
  class ClaimService
    include Callable

    def initialize(runner_id:)
      @runner_id = runner_id
    end

    def call
      ReleaseStaleService.call

      Run.transaction do
        run = Run.pending.order(priority: :desc, id: :asc).lock("FOR UPDATE SKIP LOCKED").first
        claim(run) if run
        run
      end
    end

    private

    def claim(run)
      now = Time.current
      run.update!(status: "claimed", runner_id: @runner_id, claimed_at: now, heartbeat_at: now, error: nil)
      run.experiment.running! if run.experiment.queued?
    end
  end
end
