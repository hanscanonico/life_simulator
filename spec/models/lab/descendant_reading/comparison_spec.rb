# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::DescendantReading::Comparison do
  subject(:comparison) { described_class.new(pairs: pairs, kills: false) }

  def reading(complexity)
    Lab::DescendantReading::Child::Reading.new(
      last_epoch: 2_000, persistence: :held, last_share: 0.9, relapse_epoch: nil, first_instructions: nil,
      last_instructions: nil, complexity: complexity, last_medians: {}, shares_by_bin: {}
    )
  end

  # One pair per `[treated, control]` verdict, three seeds a parent in order.
  def pairs_of(parent_verdicts)
    parent_verdicts.flat_map do |parent_id, verdicts|
      verdicts.each_with_index.map do |(treated, control), index|
        described_class::Pair.new(parent_id: parent_id, seed: 1001 + index, treated: treated && reading(treated),
                                  control: control && reading(control))
      end
    end
  end

  let(:favouring) { %i[rises plateau] }
  let(:against) { %i[mixed rises] }
  let(:tie) { %i[rises rises] }

  context "with six discordant pairs all favouring the treatment" do
    let(:pairs) { pairs_of(1 => [favouring, favouring, favouring], 2 => [favouring, favouring, favouring]) }

    it "holds at p = 1/64" do
      expect(comparison).to have_attributes(outcome: :held, p_value: Rational(1, 64), favouring: 6, against: 0)
    end
  end

  context "with a treatment rising more often short of p < 0.05" do
    let(:pairs) { pairs_of(1 => [favouring, favouring, favouring], 2 => [favouring, favouring, against]) }

    it "reads not shown, neither held nor refuted" do
      expect(comparison).to have_attributes(outcome: :not_shown, p_value: Rational(7, 64), reading_label: "not shown")
    end
  end

  context "with a treatment rising exactly as often as the continuation" do
    let(:pairs) { pairs_of(1 => [favouring, against, tie]) }

    it "is refuted" do
      expect(comparison.outcome).to eq(:refuted)
    end
  end

  context "with pairs not measured on both sides" do
    let(:pairs) { pairs_of(1 => [[:rises, :unmeasured], [:unmeasured, :plateau], [:rises, nil]]) }

    it "tests none of them" do
      expect(comparison).to have_attributes(measured_count: 0, outcome: :no_pairs, p_value: nil)
    end

    it "counts them apart in the parent's agreement" do
      expect(comparison.agreement).to eq([described_class::Agreement.new(parent_id: 1, treatment: 0, continuation: 0,
                                                                         ties: 0, unmeasured: 3)])
    end
  end

  describe "per-parent agreement" do
    let(:pairs) { pairs_of(1 => [favouring, against, tie], 2 => [favouring, favouring, favouring]) }

    it "counts, per parent, the pairs favouring each side and the ties" do
      expect(comparison.agreement.map { |row| row.to_h.values_at(:parent_id, :treatment, :continuation, :ties) })
        .to eq([[1, 1, 1, 1], [2, 3, 0, 0]])
    end
  end

  describe "leaving parents out" do
    context "with a held test one parent carries" do
      # 9 of 9 favour the treatment (p = 1/512); without parent 3's five, 4 of 4 is 1/16.
      let(:pairs) do
        pairs_of(1 => [favouring, favouring], 2 => [favouring, favouring],
                 3 => [favouring, favouring, favouring, favouring, favouring])
      end

      it "names the parent" do
        expect(comparison.carried_by).to eq([[3]])
      end
    end

    context "with a held test only two parents together carry" do
      # 9 of 9 (p = 1/512) over three parents of three: without any one, 6 of 6 is 1/64,
      # without any two, 3 of 3 is 1/8.
      let(:pairs) { pairs_of((1..3).index_with { [favouring, favouring, favouring] }) }

      it "names every pair of them" do
        expect(comparison.carried_by).to eq([[1, 2], [1, 3], [2, 3]])
      end
    end

    context "with a held test no one or two parents carry" do
      let(:pairs) { pairs_of((1..6).index_with { [favouring, favouring, favouring] }) }

      it "names none" do
        expect(comparison.carried_by).to eq([])
      end
    end

    context "with a test that did not hold" do
      let(:pairs) { pairs_of(1 => [favouring, favouring, favouring], 2 => [favouring, favouring, against]) }

      it "reads nothing into which parents it rests on" do
        expect(comparison.carried_by).to eq([])
      end
    end
  end

  context "with a treatment that kills replicators" do
    subject(:comparison) { described_class.new(pairs: pairs, kills: true) }

    let(:pairs) { pairs_of(1 => [favouring, favouring, favouring], 2 => [favouring, favouring, favouring]) }

    it "prints the test but does not read it as the hypothesis" do
      expect(comparison).to have_attributes(outcome: :held, reading: :kills,
                                            reading_label: "not read: relapses more than the continuation")
    end
  end
end
