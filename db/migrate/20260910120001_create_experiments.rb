# frozen_string_literal: true

class CreateExperiments < ActiveRecord::Migration[8.1]
  def change
    create_table :experiments do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :substrate, null: false, default: "soup"
      t.jsonb :param_grid, null: false, default: {}
      t.jsonb :seeds, null: false, default: []
      t.integer :epochs, null: false
      t.string :status, null: false, default: "draft"
      t.integer :runs_count, null: false, default: 0

      t.timestamps
    end

    add_index :experiments, :name, unique: true
    add_index :experiments, :slug, unique: true
  end
end
