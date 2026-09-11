# frozen_string_literal: true

class CreateRescores < ActiveRecord::Migration[8.1]
  def change
    create_table :rescores do |t|
      t.references :run, null: false, foreign_key: true
      t.integer :epoch, null: false
      t.integer :top_k, null: false
      t.bigint :replicator_count
      t.float :top_share
      t.bigint :distinct_tapes
      t.float :compress_ratio
      t.float :entropy_bits
      t.datetime :measured_at

      t.timestamps
    end

    add_index :rescores, %i[run_id epoch top_k], unique: true
  end
end
