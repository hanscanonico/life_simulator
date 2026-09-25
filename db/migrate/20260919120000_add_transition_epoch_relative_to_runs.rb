# frozen_string_literal: true

class AddTransitionEpochRelativeToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :transition_epoch_relative, :integer
  end
end
