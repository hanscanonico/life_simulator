# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::SetPriorityService do
  let(:experiment) { create(:experiment, priority: 0) }

  it "sets the experiment's priority" do
    described_class.call(experiment: experiment, priority: 7)

    expect(experiment.reload.priority).to eq(7)
  end

  it "sets the priority of the pending runs" do
    runs = create_list(:run, 2, experiment: experiment)

    described_class.call(experiment: experiment, priority: 7)

    expect(runs.map { |run| run.reload.priority }).to eq([7, 7])
  end

  it "returns the number of pending runs it moved" do
    create_list(:run, 2, experiment: experiment)

    expect(described_class.call(experiment: experiment, priority: 7)).to eq(2)
  end

  it "leaves the claimed, running and terminal runs alone" do
    untouched = %w[claimed running finished failed].map do |status|
      create(:run, :claimed, experiment: experiment, status: status, priority: 1)
    end

    described_class.call(experiment: experiment, priority: 7)

    expect(untouched.map { |run| run.reload.priority }).to eq([1, 1, 1, 1])
  end

  it "leaves the pending runs of another experiment alone" do
    other = create(:run, experiment: create(:experiment), priority: 1)

    described_class.call(experiment: experiment, priority: 7)

    expect(other.reload.priority).to eq(1)
  end
end
