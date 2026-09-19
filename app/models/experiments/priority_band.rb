# frozen_string_literal: true

module Experiments
  # What a seed-major reprioritisation wrote: how many unfinished runs moved and the lowest
  # and highest priority they now hold, so the operator can read the band it just claimed
  # against the flat priorities of the other experiments.
  PriorityBand = Data.define(:moved, :lowest, :highest) do
    def self.empty = new(moved: 0, lowest: nil, highest: nil)
  end
end
