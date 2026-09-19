# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::SetSeedMajorPriorityService do
  let(:experiment) { create(:experiment, priority: 0) }

  it "sets the experiment's priority to the base" do
    described_class.call(experiment: experiment, base: 40)

    expect(experiment.reload.priority).to eq(40)
  end

  it "sets each unfinished run to base minus its seed" do
    runs = [0, 1, 2].map { |seed| create(:run, experiment: experiment, seed: seed, priority: 0) }

    described_class.call(experiment: experiment, base: 40)

    expect(runs.map { |run| run.reload.priority }).to eq([40, 39, 38])
  end

  it "moves the claimed and running runs too" do
    moved = %w[claimed running].map do |status|
      create(:run, :claimed, experiment: experiment, status: status, seed: 3, priority: 1)
    end

    described_class.call(experiment: experiment, base: 40)

    expect(moved.map { |run| run.reload.priority }).to eq([37, 37])
  end

  it "leaves the terminal runs alone" do
    untouched = %w[finished failed].map do |status|
      create(:run, :claimed, experiment: experiment, status: status, seed: 1, priority: 1)
    end

    described_class.call(experiment: experiment, base: 40)

    expect(untouched.map { |run| run.reload.priority }).to eq([1, 1])
  end

  it "leaves another experiment's runs alone" do
    other = create(:run, experiment: create(:experiment, priority: 5), seed: 1, priority: 5)

    described_class.call(experiment: experiment, base: 40)

    expect(other.reload.priority).to eq(5)
  end

  it "returns the band it wrote" do
    [0, 1, 2].each { |seed| create(:run, experiment: experiment, seed: seed) }
    create(:run, experiment: experiment, seed: 9, status: "finished")

    band = described_class.call(experiment: experiment, base: 40)

    expect(band).to have_attributes(moved: 3, lowest: 38, highest: 40)
  end

  it "moves every run in one statement" do
    [0, 1, 2].each { |seed| create(:run, experiment: experiment, seed: seed) }

    updates = updates_logged { described_class.call(experiment: experiment, base: 40) }

    expect(updates.grep(/UPDATE "runs"/).size).to eq(1)
  end

  context "with no unfinished run" do
    it "returns an empty band" do
      create(:run, experiment: experiment, seed: 1, status: "finished")

      expect(described_class.call(experiment: experiment, base: 40)).to eq(Experiments::PriorityBand.empty)
    end
  end

  def updates_logged
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql]
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
