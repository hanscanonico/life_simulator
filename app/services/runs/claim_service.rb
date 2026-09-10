# frozen_string_literal: true

module Runs
  # Hands the oldest pending run to a runner. `FOR UPDATE SKIP LOCKED` is what makes two
  # runners claiming at the same instant get two different runs instead of the same one.
  class ClaimService
    include Callable

    def initialize(runner_id:)
      @runner_id = runner_id
    end

    def call
      ReleaseStaleService.call

      Run.transaction do
        run = Run.pending.order(:id).lock("FOR UPDATE SKIP LOCKED").first
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
