# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::LineageDiversityReading::Hypothesis do
  subject(:hypothesis) { described_class.new(arms: arms, p_value: p_value) }

  let(:p_value) { nil }

  def reading(effective)
    verdict = if effective.nil? then :unmeasured
              elsif effective >= 2 then :polyphyletic
              elsif effective < 1.5 then :monophyletic
              else :between
              end
    Lab::LineageDiversityReading::RunReading::Reading.new(emerged: true, verdict: verdict, effective_count: effective,
                                                          decile_readings: 10, descriptive: {}, copy_latency_first: nil)
  end

  # One arm, one finished emerged run per effective count; nil is an unmeasured run.
  def arm(radius, *effective)
    rows = effective.each_with_index.map do |value, seed|
      Experiments::LineageDiversityReadingService::RunRow.new(run_id: seed, radius: radius, seed: seed,
                                                              status: "finished", emergence_epoch: 100,
                                                              reading: reading(value))
    end
    Lab::LineageDiversityReading::Arm.new(radius: radius, rows: rows, radius_emerged: nil, radius_finished: nil)
  end

  context "with the arms polyphyletic toward the shortest reach and a significant trend" do
    let(:arms) { [arm(1, 5.0, 6.0), arm(2, 3.0, 4.0), arm(4, 1.0, 1.0), arm(0, 1.0, 1.0)] }
    let(:p_value) { Rational(1, 100) }

    it "orders the read arms well-mixed first" do
      expect(hypothesis.read_arms.map(&:radius)).to eq([0, 4, 2, 1])
    end

    it "is shown" do
      expect(hypothesis).to have_attributes(outcome: :shown, shown?: true, refuted?: false)
    end
  end

  context "with a trend just at the level" do
    let(:arms) { [arm(1, 5.0, 6.0), arm(0, 1.0, 1.0)] }
    let(:p_value) { Rational(1, 20) }

    it "is neither shown nor refuted" do
      expect(hypothesis.outcome).to eq(:neither)
    end
  end

  context "with a significant trend whose shortest read reach is not polyphyletic" do
    let(:arms) { [arm(1, 1.9, 1.9), arm(0, 1.0, 1.0)] }
    let(:p_value) { Rational(1, 100) }

    it "reports a trend, not the hypothesis" do
      expect(hypothesis).to have_attributes(outcome: :neither, trend_without_polyphyly?: true)
      expect(hypothesis.line).to include("a trend, not the hypothesis")
    end
  end

  context "with every measured run monophyletic over two read arms" do
    let(:arms) { [arm(1, 1.0, 1.4), arm(2, 1.0, 1.0), arm(4), arm(0, 1.2)] }
    let(:p_value) { Rational(1, 100) }

    it "is refuted, even beside a trend, and names the unread arms" do
      expect(hypothesis).to have_attributes(outcome: :refuted, shown?: false)
      expect(hypothesis.unread_arms.map(&:label)).to eq(["radius 4", "well-mixed"])
      expect(hypothesis.line).to include("unread: radius 4, well-mixed")
    end
  end

  context "with a single polyphyletic run in an unread arm" do
    let(:arms) { [arm(1, 1.0, 1.0), arm(2, 1.0, 1.0), arm(4, 2.0)] }

    it "is not refuted" do
      expect(hypothesis.outcome).to eq(:neither)
    end
  end

  context "with one read arm" do
    let(:arms) { [arm(1, 1.0, 1.0), arm(2, 1.0, nil), arm(0)] }

    it "tests no trend and refutes nothing" do
      expect(hypothesis).to have_attributes(testable?: false, trend?: false, outcome: :neither, statistic: nil)
      expect(hypothesis.unread_arms.map(&:radius)).to eq([2, 0])
    end
  end

  describe "exclusivity" do
    # Every arrangement of a few classes over two read arms, at a significant p: shown needs a
    # polyphyletic median at the shortest reach, and refuted needs every run monophyletic.
    it "never reads shown and refuted at once" do
      values = [1.0, 1.7, 2.0, 5.0]
      outcomes = values.repeated_permutation(4).map do |a, b, c, d|
        described_class.new(arms: [arm(1, a, b), arm(0, c, d)], p_value: Rational(1, 100))
      end

      expect(outcomes).to all(satisfy { |outcome| !(outcome.shown? && outcome.refuted?) })
      expect(outcomes.map(&:outcome).uniq).to contain_exactly(:shown, :refuted, :neither)
    end
  end
end
