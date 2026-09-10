# frozen_string_literal: true

module Runs
  # Returns runs whose runner stopped heartbeating to the pending queue so another runner
  # can pick them up. `epochs_done` survives: the runner resumes from what it reported.
  class ReleaseStaleService
    include Callable

    def call
      released = Run.stale.to_a
      released.each do |run|
        run.update!(status: "pending", runner_id: nil, claimed_at: nil, heartbeat_at: nil)
      end
      released.size
    end
  end
end
