# frozen_string_literal: true

class AddComputeSecondsToRuns < ActiveRecord::Migration[8.1]
  # What a run cost, summed over every segment that ever worked on it. The runner's
  # `wall_s` covers one claim only — a resumed run has several, and the log it is written
  # to rotates — so nothing stored can say how much compute a run took. Each heartbeat
  # adds the seconds since the previous one, which makes the total survive both resumes
  # and rotation.
  def change
    add_column :runs, :compute_seconds, :float, default: 0.0, null: false
  end
end
