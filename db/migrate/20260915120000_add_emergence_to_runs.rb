# frozen_string_literal: true

class AddEmergenceToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :emergence_epoch, :integer
    add_column :runs, :emergence_witness, :string
  end
end
