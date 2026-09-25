# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::LineageDiversityReading::RunReading do
  subject(:reading) { described_class.read(samples) }

  # `size` samples from the emergence epoch on, each built by the block from its index.
  def samples_of(size = 100)
    Array.new(size) { |index| [1_000 + (10 * index), yield(index)] }
  end

  def values(share: 0.9, effective: 3.0, **descriptive)
    { "replicator_share" => share, "lineage_effective_count" => effective }.merge(descriptive.transform_keys(&:to_s))
  end

  def last_decile?(index, size = 100) = index >= size - ((size + 9) / 10)

  describe "emergence" do
    context "with a share at exactly the threshold at one sample" do
      let(:samples) { samples_of { |index| values(share: index == 40 ? 0.5 : 0.1) } }

      it "is emerged" do
        expect(reading).to be_emerged
      end
    end

    context "with a share just under the threshold throughout" do
      let(:samples) { samples_of { values(share: 0.49) } }

      it "is not emerged" do
        expect(reading).to have_attributes(emerged?: false, measured?: false, verdict: nil)
      end
    end

    context "with no share sampled" do
      let(:samples) { samples_of { |index| values(share: nil).merge("replicator_share" => index == 5 ? "0.9" : nil) } }

      it "reads a missing or non-numeric share as no reading, not as emerged" do
        expect(reading).not_to be_emerged
      end
    end
  end

  describe "the class" do
    context "with a last-decile median at exactly the polyphyletic bound" do
      let(:samples) { samples_of { |index| values(effective: last_decile?(index) ? 2.0 : 9.0) } }

      it "is polyphyletic" do
        expect(reading).to have_attributes(verdict: :polyphyletic, effective_count: 2.0, decile_size: 10)
      end
    end

    context "with a last-decile median just under the polyphyletic bound" do
      let(:samples) { samples_of { |index| values(effective: last_decile?(index) ? 1.99 : 9.0) } }

      it "is between" do
        expect(reading.verdict).to eq(:between)
      end
    end

    context "with a last-decile median at exactly the monophyletic bound" do
      let(:samples) { samples_of { |index| values(effective: last_decile?(index) ? 1.5 : 9.0) } }

      it "is between" do
        expect(reading.verdict).to eq(:between)
      end
    end

    context "with a last-decile median just under the monophyletic bound" do
      let(:samples) { samples_of { |index| values(effective: last_decile?(index) ? 1.49 : 9.0) } }

      it "is monophyletic" do
        expect(reading.verdict).to eq(:monophyletic)
      end
    end

    context "with an even last decile" do
      let(:samples) do
        samples_of { |index| values(effective: last_decile?(index) ? [1.0, 3.0][index % 2] : 9.0) }
      end

      it "takes the lower middle" do
        expect(reading.effective_count).to eq(1.0)
      end
    end

    context "with 91 samples, a last decile of exactly ten" do
      let(:samples) { samples_of(91) { values } }

      it "is measured" do
        expect(reading).to have_attributes(decile_size: 10, measured?: true)
      end
    end

    context "with 90 samples, a last decile of nine" do
      let(:samples) { samples_of(90) { values } }

      it "is unmeasured" do
        expect(reading).to have_attributes(verdict: :unmeasured, decile_size: 9, effective_count: nil,
                                           measured?: false, emerged?: true)
      end
    end

    context "with samples that do not carry the effective count as a number" do
      let(:samples) do
        samples_of(101) do |index|
          effective = index >= 91 ? 1.0 : 3.0
          values(effective: index.zero? ? nil : effective)
        end
      end

      it "skips them before cutting the decile" do
        expect(reading).to have_attributes(decile_size: 10, verdict: :monophyletic)
      end
    end
  end

  describe "the descriptive readings" do
    let(:samples) do
      samples_of do |index|
        values(lineages_over_one_percent: last_decile?(index) ? 4 : 1, copy_latency: index < 10 ? 300 : 200)
      end
    end

    it "reads last-decile medians, and copy_latency's first decile beside its last" do
      expect(reading).to have_attributes(copy_latency_first: 300)
      expect(reading.descriptive_value("lineages_over_one_percent")).to eq(4)
      expect(reading.descriptive_value("copy_latency")).to eq(200)
      expect(reading.descriptive_value("conserved_core_bytes_oriented")).to be_nil
    end
  end
end
