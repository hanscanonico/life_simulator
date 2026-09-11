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

      run = Run.transaction do
        candidate = Run.pending.order(priority: :desc, id: :asc).lock("FOR UPDATE SKIP LOCKED").first
        claim(candidate) if candidate
        candidate
      end
      log_claim(run) if run
      run
    end

    private

    def claim(run)
      now = Time.current
      run.update!(status: "claimed", runner_id: @runner_id, claimed_at: now, heartbeat_at: now, error: nil)
      run.experiment.running! if run.experiment.queued?
    end

    def log_claim(run)
      Rails.logger.info("event=run_claimed run_id=#{run.id} runner_id=#{@runner_id.to_s.truncate(200).inspect}")
    end
  end
end
