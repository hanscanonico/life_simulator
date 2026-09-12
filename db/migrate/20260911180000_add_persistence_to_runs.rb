# frozen_string_literal: true

class AddPersistenceToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :persistence, :jsonb, default: {}, null: false
  end
end
