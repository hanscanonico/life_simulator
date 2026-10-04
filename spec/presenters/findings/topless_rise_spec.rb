# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::ToplessRise do
  subject(:reading) { described_class.build(Experiments::ToplessRiseReadingService.call(experiment: experiment)) }

  let(:experiment) { topless_rise_experiment }

  before do
    topless_rise_parents
    Experiments::DescendantSweepBuilderService.call(experiment)
  end

  context "with one rise child and two capped children rising late" do
    before do
      topless_rise_children(experiment, :rise).each_with_index do |run, index|
        topless_rise_sample(run, fifth: 9, last: index.zero? ? 10 : 9)
      end
      topless_rise_children(experiment, :capped).each_with_index do |run, index|
        topless_rise_sample(run, fifth: 7, last: index < 2 ? 8 : 7)
      end
      topless_rise_children(experiment, :none).each { |run| topless_rise_sample(run, fifth: 0) }
    end

    it "finds each pre-registered test by its hypothesis" do
      expect([reading.rise, reading.rise_paid].map(&:hypothesis)).to eq(%w[H-rise H-rise-paid])
    end

    it "reads the climb as stopped, H-rise not shown and H-rise-paid refuted" do
      expect([reading.rise, reading.rise_paid].map(&:outcome)).to eq(%i[not_shown refuted])
      expect(reading).to be_climb_stopped
    end

    it "lists each arm's late risers in parent order" do
      rise = topless_rise_children(experiment, :rise)
      capped = topless_rise_children(experiment, :capped)

      expect(reading.late_risers(:rise).map(&:run_id)).to eq([rise.first.id])
      expect(reading.late_risers(:capped).map(&:run_id)).to eq(capped.first(2).map(&:id))
      expect(reading.late_risers(:none)).to be_empty
    end

    it "counts no relapse, extinction or ceilinged child" do
      expect(%i[rise capped none].map { |key| reading.relapse_count(key) }).to eq([0, 0, 0])
      expect([reading.extinct_count, reading.ceilinged_count]).to eq([0, 0])
    end
  end

  context "with every rise child rising late and no control" do
    before do
      topless_rise_children(experiment, :rise).each { |run| topless_rise_sample(run, fifth: 9, last: 10) }
      topless_rise_children(experiment, :capped).each { |run| topless_rise_sample(run, fifth: 7) }
      topless_rise_children(experiment, :none).each { |run| topless_rise_sample(run, fifth: 0) }
    end

    it "reads the climb as stopped while the sign test cannot show three pairs" do
      expect(reading.rise.comparison).to have_attributes(favouring: 3, against: 0)
      expect(reading).to be_climb_stopped
    end
  end

  context "with a relapsed and an extinct child" do
    before do
      none = topless_rise_children(experiment, :none)
      topless_rise_children(experiment, :rise).each { |run| topless_rise_sample(run, fifth: 9) }
      topless_rise_children(experiment, :capped).each { |run| topless_rise_sample(run, fifth: 7) }
      topless_rise_sample(none.first, fifth: 0, share: 0.0)
      none.drop(1).each { |run| topless_rise_sample(run, fifth: 0) }
    end

    it "counts them" do
      expect(reading.relapse_count(:none)).to eq(1)
      expect(reading.extinct_count).to eq(1)
    end
  end
end
