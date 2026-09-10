# frozen_string_literal: true

module Runs
  # Returns runs whose runner stopped heartbeating to the pending queue so another runner
  # can pick them up. `epochs_done` survives: the runner resumes from what it reported.
  # Every claim poll runs this, twelve runners over, so it is one statement and not a loop.
  class ReleaseStaleService
    include Callable

    def call
      Run.stale.update_all(status: "pending", runner_id: nil, claimed_at: nil, heartbeat_at: nil,
                           updated_at: Time.current)
    end
  end
end
