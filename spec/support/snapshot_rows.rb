# frozen_string_literal: true

# The pruning specs need a run carrying dozens of snapshots and never read a snapshot's
# contents, so they insert the rows in one statement instead of paying the factory per row.
module SnapshotRows
  def insert_snapshots(run, epochs)
    now = Time.current
    rows = epochs.map do |epoch|
      { run_id: run.id, epoch: epoch, blob: "world-bytes", png: "png-bytes",
        created_at: now, updated_at: now }
    end

    Snapshot.insert_all(rows)
  end
end

RSpec.configure { |config| config.include SnapshotRows }
