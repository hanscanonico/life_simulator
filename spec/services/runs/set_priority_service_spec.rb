# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::SetPriorityService do
  let(:experiment) { create(:experiment, priority: 0) }

  it "sets the priority of a pending run" do
    run = create(:run, experiment: experiment, priority: 0)

    described_class.call(run: run, priority: 9)

    expect(run.reload.priority).to eq(9)
  end

  it "sets the priority of a running run, which it keeps once released" do
    run = create(:run, :claimed, experiment: experiment, status: "running", priority: 1)

    described_class.call(run: run, priority: 9)

    expect(run.reload.priority).to eq(9)
  end

  it "returns the priority it left behind" do
    run = create(:run, experiment: experiment, priority: 3)

    expect(described_class.call(run: run, priority: 9)).to eq(3)
  end

  it "leaves the experiment's priority alone" do
    run = create(:run, experiment: experiment)

    described_class.call(run: run, priority: 9)

    expect(experiment.reload.priority).to eq(0)
  end

  it "refuses a finished run" do
    run = create(:run, experiment: experiment, status: "finished", priority: 1)

    expect { described_class.call(run: run, priority: 9) }
      .to raise_error(ArgumentError, /Run #{run.id} is finished/)
    expect(run.reload.priority).to eq(1)
  end

  it "refuses a failed run" do
    run = create(:run, :just_failed, experiment: experiment, priority: 1)

    expect { described_class.call(run: run, priority: 9) }
      .to raise_error(ArgumentError, /Run #{run.id} is failed/)
    expect(run.reload.priority).to eq(1)
  end
end
