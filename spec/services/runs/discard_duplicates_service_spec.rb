# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::DiscardDuplicatesService do
  subject(:discard) { described_class.call(experiment: experiment) }

  let(:experiment) { create(:experiment) }

  def duplicate(*traits, radius: 1, seed: 7, params: nil)
    create(:run, *traits, experiment: experiment, seed: seed,
                          params: params || Lab::Schema.run_defaults.merge("radius" => radius))
  end

  it "keeps the lowest id of a pending group and deletes the rest" do
    kept = duplicate
    second = duplicate
    third = duplicate

    expect(discard).to eq([second.id, third.id])
    expect(experiment.runs.pluck(:id)).to eq([kept.id])
  end

  it "keeps the run that is already claimed, whatever its id" do
    pending_run = duplicate
    claimed = duplicate(:claimed)

    expect(discard).to eq([pending_run.id])
    expect(experiment.runs.pluck(:id)).to eq([claimed.id])
  end

  it "keeps both runs of a group where none is pending" do
    duplicate(:claimed)
    duplicate(:claimed)

    expect { discard }.not_to change(Run, :count)
  end

  it "leaves a run that has no duplicate" do
    duplicate(radius: 1)
    duplicate(radius: 2)

    expect(discard).to eq([])
  end

  it "treats a different seed on the same arm as a different run" do
    duplicate(seed: 1)
    duplicate(seed: 2)

    expect { discard }.not_to change(Run, :count)
  end

  it "counts a run stored before the schema grew a parameter as the same arm" do
    kept = duplicate
    stale = duplicate(params: Lab::Schema.run_defaults.merge("radius" => 1).except("ops"))

    expect(discard).to eq([stale.id])
    expect(experiment.runs.pluck(:id)).to eq([kept.id])
  end

  it "leaves the duplicates of another experiment alone" do
    other = create(:experiment)
    twins = create_list(:run, 2, experiment: other, seed: 7, params: Lab::Schema.run_defaults)

    discard

    expect(other.runs.pluck(:id)).to eq(twins.map(&:id))
  end

  context "with a duplicate that carries measurements" do
    it "refuses the whole batch" do
      duplicate
      create(:sample, run: duplicate)

      expect { discard }.to raise_error(ArgumentError, /carry samples or snapshots/)
      expect(experiment.runs.count).to eq(2)
    end
  end
end
