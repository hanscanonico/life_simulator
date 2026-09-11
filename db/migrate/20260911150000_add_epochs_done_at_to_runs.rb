# frozen_string_literal: true

class AddEpochsDoneAtToRuns < ActiveRecord::Migration[8.1]
  # When progress last moved, as opposed to when the runner last spoke: the heartbeat
  # touches `heartbeat_at` and `updated_at` every 30 s whether or not the simulation
  # advanced, so nothing already stored can tell a wedged run from a slow one. A nullable
  # column with no default takes no table rewrite, so its exclusive lock is held for an
  # instant and the live runs keep heartbeating through it; the backfill covers the runs in
  # flight at deploy time, which would otherwise read as stalled until their next heartbeat.
  def up
    add_column :runs, :epochs_done_at, :datetime
    execute <<~SQL.squish
      UPDATE runs SET epochs_done_at = heartbeat_at
      WHERE status IN ('claimed', 'running') AND heartbeat_at IS NOT NULL
    SQL
  end

  def down
    remove_column :runs, :epochs_done_at
  end
end
