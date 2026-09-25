# frozen_string_literal: true

# A descendant sweep starts its runs from other runs' stored worlds, so the rule that picks
# those parents is part of the experiment, as its grid and seeds are. Empty for a founding
# sweep.
class AddParentsToExperiments < ActiveRecord::Migration[8.1]
  def change
    add_column :experiments, :parents, :jsonb, default: {}, null: false
  end
end
