# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::FromEmerged do
  subject(:reading) { described_class.build(Experiments::FromEmergedReadingService.call(experiment: experiment)) }

  let(:experiment) { from_emerged_experiment }

  before do
    [5, 120, 121].each { |seed| from_emerged_parent(seed: seed) }
    Experiments::DescendantSweepBuilderService.call(experiment)
    experiment.runs.each { |run| from_emerged_sample(run) }
    from_emerged_children(experiment, 2).each { |run| run.samples.delete_all && from_emerged_sample(run, last: 1_000) }
    from_emerged_children(experiment, 0).each { |run| run.samples.delete_all && from_emerged_sample(run, last: 5_000) }
  end

  it "sizes the latency effect per treatment over the held-out children only" do
    expect(reading.latency_effects.map { |effect| [effect.name, effect.measured, effect.ratio, effect.falling] })
      .to eq([["continuation", 6, Rational(5, 4), 0], ["economy 2048", 6, 1, 0],
              ["economy 8192", 6, Rational(1, 4), 6], ["host mode", 6, 1, 0]])
  end

  it "takes the medians of the children's first- and last-decile latencies" do
    expect(reading.economy_effects.last).to have_attributes(first_latency: 4_000, last_latency: 1_000)
  end

  it "states the claim from the medians" do
    expect(reading.claim_sentence)
      .to eq("Over the held-out children, the median ratio of last-decile to first-decile copy_latency was " \
             "1 under economy 2048 and 0.25 under economy 8192, against 1.25 in the continuation.")
  end

  it "shows H3-latency on both economy arms, each against a slowing continuation" do
    expect(reading).to be_latency_shown
  end

  it "counts the held-out parents whose pairs favour the treatment" do
    expect(reading.latency_tests.map { |test| reading.parents_favouring(test) }).to eq([2, 2])
  end

  it "reads no economy arm as keeping complexity rising" do
    expect(reading).not_to be_complexity_rise_shown
  end
end
