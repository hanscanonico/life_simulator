# frozen_string_literal: true

class CreateSamples < ActiveRecord::Migration[8.1]
  def change
    create_table :samples do |t|
      t.references :run, null: false, foreign_key: true, index: false
      t.integer :epoch, null: false
      t.jsonb :values, null: false, default: {}

      t.timestamps
    end

    add_index :samples, %i[run_id epoch], unique: true
  end
end
