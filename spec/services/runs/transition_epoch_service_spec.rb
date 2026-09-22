# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::TransitionEpochService do
  subject(:epoch) { described_class.call(samples: samples) }

  # A cap-64 arm: the soup starts near 0.98, where the constant threshold was chosen, and
  # the two rules read the same crossing — the series the engine's tracker reads as 510
  # too (`a_run_that_starts_high_and_falls_reads_the_same_epoch_on_both_rules`, metrics.rs).
  context "with a run that starts high and falls" do
    let(:samples) { series(0.98, 0.5) }

    it "reads the epoch the companion rule reads" do
      expect(epoch).to eq(510)
      expect(Runs::ConstantTransitionEpochService.call(samples: samples)).to eq(510)
    end
  end

  # A cap-512 arm: the soup starts in the constant threshold's neighbourhood and never
  # falls far from its own start, so it crosses the companion rule and nothing else
  # (`a_run_that_starts_at_the_threshold_flags_on_the_constant_rule_alone`, metrics.rs).
  context "with a run that starts low and drifts" do
    let(:samples) { series(0.75, 0.46) }

    it "reads no crossing where the companion rule reads one" do
      expect(epoch).to be_nil
      expect(Runs::ConstantTransitionEpochService.call(samples: samples)).to eq(510)
    end
  end

  context "with a run that fell inside the baseline window and sampled no further" do
    let(:samples) { early_fall }

    it "reads nothing, the baseline never having closed" do
      expect(epoch).to be_nil
    end

    context "with one sample past the window" do
      let(:samples) { early_fall + [[510, values(0.1)]] }

      it "reads the crossing the closed window holds" do
        expect(epoch).to eq(210)
      end
    end
  end

  context "with a run whose first sample comes after the baseline window" do
    let(:samples) { series(0.98, 0.1).reject { |sample_epoch, _| sample_epoch <= 500 } }

    it "reads nothing, there being no baseline to read against" do
      expect(epoch).to be_nil
    end
  end

  context "with a run read off its stored samples" do
    let(:run) { create(:run) }

    it "reads the same epoch the samples give" do
      series(0.98, 0.5).each do |sample_epoch, values|
        create(:sample, run: run, epoch: sample_epoch, values: values)
      end

      expect(described_class.call(run: run)).to eq(510)
    end
  end

  # A run that falls at epoch 210, well inside the window its own baseline is drawn from.
  def early_fall
    (0..20).map { |sample| [sample * 10, values(0.98)] } +
      (21..50).map { |sample| [sample * 10, values(0.1)] }
  end

  # A baseline window of samples at `start`, then a run of samples at `fallen`.
  def series(start, fallen)
    (0..50).map { |sample| [sample * 10, values(start)] } +
      (51..80).map { |sample| [sample * 10, values(fallen)] }
  end

  def values(ratio)
    { "compress_ratio" => ratio, "op_density" => 0.5, "alphabet_size" => 200 }
  end
end
