# frozen_string_literal: true

class AddPriorityToRunsAndExperiments < ActiveRecord::Migration[8.1]
  def change
    add_column :experiments, :priority, :integer, null: false, default: 0
    add_column :runs, :priority, :integer, null: false, default: 0

    # `priority DESC` matches the claim's ORDER BY exactly; a plain ascending index makes
    # Postgres sort the whole top-priority group on every claim.
    add_index :runs, %i[status priority id], order: { priority: :desc }
  end
end
