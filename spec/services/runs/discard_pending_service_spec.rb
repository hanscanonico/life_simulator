# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::DiscardPendingService do
  subject(:discard) { described_class.call(experiment: experiment, param: "radius", value: "64") }

  let(:experiment) { create(:experiment) }

  def run_on(radius, *traits)
    create(:run, *traits, experiment: experiment, params: Lab::Schema.run_defaults.merge("radius" => radius))
  end

  it "deletes the pending runs whose parameter holds the value" do
    discarded = run_on(64)
    run_on(1)

    expect { discard }.to change { experiment.runs.count }.by(-1)
    expect(Run.exists?(discarded.id)).to be(false)
  end

  it "returns the ids it removed, in order" do
    first = run_on(64)
    second = run_on(64)

    expect(discard).to eq([first.id, second.id])
  end

  it "matches a stored value written as a float" do
    discarded = run_on(64.0)

    expect(discard).to eq([discarded.id])
  end

  it "matches a run that inherited the value from the engine defaults" do
    inherited = create(:run, experiment: experiment, params: Lab::Schema.run_defaults.except("radius"))

    expect(described_class.call(experiment: experiment, param: "radius", value: "1")).to eq([inherited.id])
  end

  it "leaves the runs of another experiment alone" do
    other = create(:run, params: Lab::Schema.run_defaults.merge("radius" => 64))

    discard

    expect(Run.exists?(other.id)).to be(true)
  end

  context "with a claimed run on the same arm" do
    it "leaves it in place" do
      claimed = run_on(64, :claimed)
      pending = run_on(64)

      expect(discard).to eq([pending.id])
      expect(claimed.reload).to be_claimed
    end
  end

  context "with a terminal run on the same arm" do
    it "leaves it in place" do
      finished = run_on(64)
      finished.update!(status: "finished")

      expect { discard }.not_to change(Run, :count)
    end
  end

  context "with a pending run that carries measurements" do
    it "refuses the whole batch" do
      measured = run_on(64)
      create(:sample, run: measured)
      run_on(64)

      expect { discard }.to raise_error(ArgumentError, /carry samples or snapshots/)
      expect(experiment.runs.count).to eq(2)
    end

    it "refuses on a snapshot too" do
      create(:snapshot, run: run_on(64))

      expect { discard }.to raise_error(ArgumentError, /carry samples or snapshots/)
    end
  end

  context "with a parameter the engine schema does not have" do
    it "refuses to run" do
      expect { described_class.call(experiment: experiment, param: "colour", value: "red") }
        .to raise_error(ArgumentError, /no colour run parameter/)
    end
  end
end
