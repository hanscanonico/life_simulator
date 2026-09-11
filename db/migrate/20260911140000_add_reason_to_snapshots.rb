# frozen_string_literal: true

class AddReasonToSnapshots < ActiveRecord::Migration[8.1]
  # The default covers the rows already stored and the runners mid-run when this ships:
  # every snapshot taken before the reason travelled was an epoch-cadence one.
  def change
    add_column :snapshots, :reason, :string, null: false, default: "cadence"
  end
end
