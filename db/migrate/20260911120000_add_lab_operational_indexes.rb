# frozen_string_literal: true

class AddLabOperationalIndexes < ActiveRecord::Migration[8.1]
  # `samples` grows by thousands of rows a minute and `runs` is claimed and heartbeated
  # continuously, so these indexes are built without taking a write lock on either table.
  disable_ddl_transaction!

  def change
    add_index :samples, :created_at, algorithm: :concurrently
    add_index :runs, :heartbeat_at, algorithm: :concurrently
    add_index :runs, :finished_at, where: "status IN ('finished', 'failed')",
                                   name: "index_runs_on_finished_at_terminal", algorithm: :concurrently
  end
end
