# frozen_string_literal: true

module Runs
  # Stores what a terminal run's samples now say became of it, for the backfill tasks that
  # rewrite a reading after the fact — a transition epoch moved by
  # `lab:backfill_transitions` changes the summary that hangs off it, and the two must not
  # be allowed to disagree. Returns true when the stored value changed.
  class PersistenceRefreshService
    include Callable

    def initialize(run:)
      @run = run
    end

    def call
      summary = PersistenceSummaryService.call(run: @run).to_h.stringify_keys
      return false if summary == @run.persistence

      @run.update!(persistence: summary)
      true
    end
  end
end
