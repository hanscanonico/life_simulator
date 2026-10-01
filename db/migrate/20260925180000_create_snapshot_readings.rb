# frozen_string_literal: true

class CreateSnapshotReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :snapshot_readings do |t|
      t.references :run, null: false, foreign_key: true, index: false
      t.integer :epoch, null: false
      t.string :instrument, null: false
      t.integer :source_epoch, null: false
      t.jsonb :values, null: false, default: {}
      t.datetime :measured_at

      t.timestamps
    end

    add_index :snapshot_readings, %i[run_id instrument epoch], unique: true
    add_index :snapshot_readings, %i[run_id epoch]
  end
end
