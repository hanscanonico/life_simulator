# frozen_string_literal: true

class AddSeedsByArmToExperiments < ActiveRecord::Migration[8.1]
  def change
    add_column :experiments, :seeds_by_arm, :jsonb, default: {}, null: false
  end
end
