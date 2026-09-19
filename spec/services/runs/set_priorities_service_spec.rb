# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::SetPrioritiesService do
  let(:experiment) { create(:experiment, priority: 0) }

  it "sets the priority of every run of the batch" do
    runs = create_list(:run, 3, experiment: experiment, priority: 0)

    described_class.call(pairs: runs.map.with_index { |run, i| "#{run.id}:#{40 - i}" }.join(";"))

    expect(runs.map { |run| run.reload.priority }).to eq([40, 39, 38])
  end

  it "moves a running run" do
    run = create(:run, :claimed, experiment: experiment, status: "running", priority: 1)

    described_class.call(pairs: "#{run.id}:9")

    expect(run.reload.priority).to eq(9)
  end

  it "returns the priority each run left behind" do
    run = create(:run, experiment: experiment, priority: 3)

    moves = described_class.call(pairs: "#{run.id}:9")

    expect(moves).to contain_exactly(have_attributes(run: run, previous: 3, priority: 9))
  end

  it "leaves the experiments' own priorities alone" do
    run = create(:run, experiment: experiment)

    described_class.call(pairs: "#{run.id}:9")

    expect(experiment.reload.priority).to eq(0)
  end

  it "moves runs of two experiments in one batch" do
    here = create(:run, experiment: experiment, priority: 0)
    there = create(:run, experiment: create(:experiment), priority: 0)

    described_class.call(pairs: "#{here.id}:9;#{there.id}:8")

    expect([here.reload.priority, there.reload.priority]).to eq([9, 8])
  end

  it "accepts a negative priority" do
    run = create(:run, experiment: experiment, priority: 0)

    described_class.call(pairs: "#{run.id}:-5")

    expect(run.reload.priority).to eq(-5)
  end

  context "with a malformed pair" do
    it "names the pair and writes nothing" do
      run = create(:run, experiment: experiment, priority: 0)

      expect { described_class.call(pairs: "#{run.id}:9;12-8") }
        .to raise_error(ArgumentError, /Malformed pairs "12-8"; expected id:priority/)
      expect(run.reload.priority).to eq(0)
    end
  end

  context "with no pair at all" do
    it "asks for one" do
      expect { described_class.call(pairs: "") }.to raise_error(ArgumentError, /at least one pair/)
    end
  end

  context "with an unknown run" do
    it "names it and writes nothing" do
      run = create(:run, experiment: experiment, priority: 0)
      unknown = Run.maximum(:id) + 1

      expect { described_class.call(pairs: "#{run.id}:9;#{unknown}:8") }
        .to raise_error(ArgumentError, /Unknown runs #{unknown}/)
      expect(run.reload.priority).to eq(0)
    end
  end

  context "with a terminal run" do
    it "refuses the whole batch" do
      run = create(:run, experiment: experiment, priority: 0)
      finished = create(:run, experiment: experiment, status: "finished", priority: 1)

      expect { described_class.call(pairs: "#{run.id}:9;#{finished.id}:8") }
        .to raise_error(ArgumentError, /Terminal runs #{finished.id}/)
      expect([run.reload.priority, finished.reload.priority]).to eq([0, 1])
    end
  end
end
