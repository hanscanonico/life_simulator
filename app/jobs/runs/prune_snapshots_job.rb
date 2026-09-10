# frozen_string_literal: true

module Runs
  # Thins the snapshots of runs that finished recently; scheduled in config/recurring.yml.
  class PruneSnapshotsJob < ApplicationJob
    queue_as :default

    # How far back a scheduled pass looks: a run that finished earlier was already pruned.
    WINDOW = 1.day

    def perform
      PruneSnapshotsService.prunable(since: WINDOW.ago).sum { |run| PruneSnapshotsService.call(run: run) }
    end
  end
end
