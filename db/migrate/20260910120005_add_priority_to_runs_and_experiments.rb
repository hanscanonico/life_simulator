# frozen_string_literal: true

class AddPriorityToRunsAndExperiments < ActiveRecord::Migration[8.1]
  def change
    add_column :experiments, :priority, :integer, null: false, default: 0
    add_column :runs, :priority, :integer, null: false, default: 0

    add_index :runs, %i[status priority id]
  end
end
