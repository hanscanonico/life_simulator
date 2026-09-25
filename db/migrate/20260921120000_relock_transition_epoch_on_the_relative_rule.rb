# frozen_string_literal: true

# The 2026-09-21 record entry makes the relative rule the transition rule, so the two
# stored readings swap roles. No value moves: each column keeps the numbers it holds and
# takes the name of the role that rule now plays, which is what makes the swap reversible
# and the stored corpus readable at every point of it.
class RelockTransitionEpochOnTheRelativeRule < ActiveRecord::Migration[8.1]
  def change
    rename_column :runs, :transition_epoch, :transition_epoch_constant
    rename_column :runs, :transition_epoch_relative, :transition_epoch
  end
end
