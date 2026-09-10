# frozen_string_literal: true

class CreateRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :runs do |t|
      t.references :experiment, null: false, foreign_key: true
      t.jsonb :params, null: false, default: {}
      t.bigint :seed, null: false
      t.integer :epochs, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :claimed_at
      t.datetime :heartbeat_at
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :epochs_done, null: false, default: 0
      t.integer :transition_epoch
      t.jsonb :summary, null: false, default: {}
      t.string :runner_id
      t.text :error

      t.timestamps
    end

    add_index :runs, %i[status id]
  end
end
