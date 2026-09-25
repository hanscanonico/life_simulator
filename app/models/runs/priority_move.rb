# frozen_string_literal: true

module Runs
  # One run of a batch reprioritisation: the run that moved and the priority it left behind.
  PriorityMove = Data.define(:run, :previous, :priority)
end
