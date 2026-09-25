# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::FromEmergedHeldout::Pairs do
  let(:child_row) { Data.define(:reading, :heldout) }

  def child(ratio: nil, complexity: :plateau, extinct: false, relapse: nil)
    reading = Lab::DescendantReading::Child::Reading.new(
      last_epoch: 40_000, persistence: :held, last_share: 0.9, relapse_epoch: nil, first_instructions: nil,
      last_instructions: nil, complexity: complexity, last_medians: {}, shares_by_bin: {}
    )
    heldout = Lab::FromEmergedHeldout::Child::Reading.new(
      read: true, extinct: extinct, settled_relapse_epoch: relapse, first_latency: ratio && 1_000,
      last_latency: ratio && (1_000 * ratio)
    )
    child_row.new(reading: reading, heldout: heldout)
  end

  def pair(kind, treated, control)
    Lab::FromEmergedHeldout::Pairs.const_get(kind).new(parent_id: 1, seed: 1001, treated: treated, control: control)
  end

  describe described_class::Latency do
    it "favours the treatment whose ratio is lower" do
      expect(pair(:Latency, child(ratio: 0.5), child(ratio: 0.9))).to have_attributes(
        measured?: true, favours_treatment?: true, favours_continuation?: false
      )
    end

    it "favours the continuation whose ratio is lower" do
      expect(pair(:Latency, child(ratio: 0.9), child(ratio: 0.5)).favours_continuation?).to be(true)
    end

    it "ties on equal ratios" do
      expect(pair(:Latency, child(ratio: 0.5), child(ratio: 0.5)))
        .to have_attributes(measured?: true, favours_treatment?: false, favours_continuation?: false)
    end

    it "is not measured with either side unmeasured" do
      expect([pair(:Latency, child, child(ratio: 0.5)), pair(:Latency, child(ratio: 0.5), nil)].map(&:measured?))
        .to eq([false, false])
    end
  end

  describe described_class::Survivors do
    it "favours the treatment that rises against a continuation that does not" do
      expect(pair(:Survivors, child(complexity: :rises), child(complexity: :mixed)).favours_treatment?).to be(true)
    end

    it "favours the continuation in the reverse case" do
      expect(pair(:Survivors, child(complexity: :plateau), child(complexity: :rises)).favours_continuation?)
        .to be(true)
    end

    it "leaves out a pair with a settled relapse on either side" do
      expect(pair(:Survivors, child(complexity: :rises, relapse: 21_500), child).measured?).to be(false)
    end

    it "leaves out a pair with an extinct child on either side" do
      expect(pair(:Survivors, child(complexity: :rises), child(extinct: true)).measured?).to be(false)
    end

    it "leaves out a pair with an unmeasured child" do
      expect(pair(:Survivors, child(complexity: :rises), child(complexity: :unmeasured)).measured?).to be(false)
    end
  end

  # The pairs go through the original entry's comparison; its outcome :held reads "shown".
  describe "the sign test, per economy arm" do
    def test_of(ratios)
      pairs = ratios.each_with_index.map do |(treated, control), index|
        described_class::Latency.new(parent_id: index / 3, seed: 1001 + (index % 3), treated: child(ratio: treated),
                                     control: child(ratio: control))
      end
      Lab::FromEmergedHeldout::Test.new(
        hypothesis: "H3-latency", treatment: Experiments::FromEmergedReadingService::Treatment.new(
          name: "economy 8192", bundle: { "steal_amount" => 1024 }
        ), comparison: Lab::DescendantReading::Comparison.new(pairs: pairs, kills: false)
      )
    end

    let(:favouring) { [0.5, 0.9] }
    let(:against) { [0.9, 0.5] }
    let(:tie) { [0.5, 0.5] }

    it "is shown with five favouring pairs of five, p = 1/32" do
      expect(test_of([favouring] * 5)).to have_attributes(outcome_label: "shown", badge_class: "badge-success")
    end

    it "is not shown with four favouring pairs of four, p = 1/16" do
      expect(test_of([favouring] * 4).outcome_label).to eq("not shown")
    end

    it "is refuted with as many pairs against as for" do
      expect(test_of([favouring, against, tie]).outcome_label).to eq("refuted")
    end

    it "is refuted with measured pairs that all tie" do
      expect(test_of([tie, tie]).outcome_label).to eq("refuted")
    end

    it "reads no measured pairs with none" do
      expect(test_of([]).outcome_label).to eq("no measured pairs")
    end

    it "drops ties from the test" do
      expect(test_of(([favouring] * 5) + ([tie] * 4)).comparison.p_value).to eq(Rational(1, 32))
    end

    it "lists the parents a shown result rests on" do
      expect(test_of([favouring] * 6).comparison.carried_by).to eq([[0], [1]])
    end
  end
end
