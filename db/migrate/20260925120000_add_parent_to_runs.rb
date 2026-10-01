# frozen_string_literal: true

# A descendant run starts from a stored world of a finished parent run: the parent and the
# epoch of that world are its identity beside (params, seed), and one without the other
# names no world at all.
class AddParentToRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :runs, :parent_run, foreign_key: { to_table: :runs }, null: true, index: true
    add_column :runs, :parent_epoch, :integer
    add_check_constraint :runs, "(parent_run_id IS NULL) = (parent_epoch IS NULL)", name: "runs_parent_complete"
  end
end
