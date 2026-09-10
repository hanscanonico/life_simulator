# frozen_string_literal: true

class CreateSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :snapshots do |t|
      t.references :run, null: false, foreign_key: true, index: false
      t.integer :epoch, null: false
      t.binary :blob
      t.binary :png

      t.timestamps
    end

    add_index :snapshots, %i[run_id epoch], unique: true
  end
end
