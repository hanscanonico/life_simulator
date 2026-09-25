# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::DescendantReading::Child do
  subject(:reading) { described_class.read(samples, parent_epoch: parent_epoch) }

  # `size` own samples 50 epochs apart, each built by the block from its index, so a
  # decile is `size / 10` of them.
  def own_samples(size = 100)
    Array.new(size) { |index| [parent_epoch + (50 * (index + 1)), yield(index)] }
  end

  def parent_epoch = 1_000

  def values(share: 0.9, replicates: true, instructions: 100)
    { "replicator_share" => share, "dominant_self_replicates" => replicates,
      "dominant_instruction_count" => instructions }
  end

  def last_decile?(index) = index >= 90

  def first_decile?(index) = index < 10

  describe "persistence" do
    context "with a last decile at exactly the held share" do
      let(:samples) { own_samples { |index| values(share: last_decile?(index) ? 0.5 : 0.9) } }

      it "holds" do
        expect(reading).to have_attributes(persistence: :held, last_share: 0.5, relapse_epoch: nil)
      end
    end

    context "with a last decile just under the held share" do
      let(:samples) { own_samples { |index| values(share: last_decile?(index) ? 0.49 : 0.9) } }

      it "relapsed on its last decile alone, with no relapse epoch" do
        expect(reading).to have_attributes(persistence: :relapsed, relapse_epoch: nil)
      end
    end

    context "with three samples running below the floor" do
      let(:samples) { own_samples { |index| values(share: (40..42).cover?(index) ? 0.09 : 0.9) } }

      it "relapsed at the first of the three" do
        expect(reading).to have_attributes(persistence: :relapsed, relapse_epoch: parent_epoch + (50 * 41))
      end
    end

    context "with two samples below the floor, then a third after one above it" do
      let(:samples) { own_samples { |index| values(share: [40, 41, 43].include?(index) ? 0.09 : 0.9) } }

      it "holds" do
        expect(reading.persistence).to eq(:held)
      end
    end

    context "with three samples running at exactly the floor" do
      let(:samples) { own_samples { |index| values(share: (40..42).cover?(index) ? 0.1 : 0.9) } }

      it "holds: the floor is a share below 0.1" do
        expect(reading.persistence).to eq(:held)
      end
    end

    context "with no share sampled" do
      let(:samples) { own_samples { values(share: nil) } }

      it "reads no persistence at all" do
        expect(reading.persistence).to be_nil
      end
    end
  end

  describe "complexity" do
    def instructions(first:, last:)
      own_samples do |index|
        count = if first_decile?(index) then first
                elsif last_decile?(index) then last
                else 150
                end
        values(instructions: count)
      end
    end

    {
      [100, 120] => :rises,
      [100, 119] => :mixed,
      [100, 110] => :plateau,
      [100, 111] => :mixed,
      [100, 90] => :plateau,
      [100, 89] => :mixed
    }.each do |(first, last), verdict|
      context "with a first-decile median of #{first} and a last-decile median of #{last}" do
        let(:samples) { instructions(first: first, last: last) }

        it "reads #{verdict}" do
          expect(reading).to have_attributes(complexity: verdict, first_instructions: first, last_instructions: last)
        end
      end
    end

    context "with 10 self-replicating samples in each decile" do
      let(:samples) { own_samples { |index| values(replicates: first_decile?(index) || last_decile?(index)) } }

      it "is measured" do
        expect(reading.complexity).to eq(:plateau)
      end
    end

    context "with 9 self-replicating samples in the first decile" do
      let(:samples) { own_samples { |index| values(replicates: index != 0) } }

      it "is unmeasured" do
        expect(reading).to have_attributes(complexity: :unmeasured, first_instructions: nil)
      end
    end

    context "with dominant tapes that do not self-replicate" do
      let(:samples) do
        own_samples do |index|
          values(replicates: !first_decile?(index) && !last_decile?(index), instructions: index)
        end
      end

      it "reads none of their instruction counts" do
        expect(reading.complexity).to eq(:unmeasured)
      end
    end

    context "with the decile's own size of ceil(n / 10)" do
      let(:samples) do
        own_samples(101) { |index| values(instructions: index < 5 ? 100 : 200) }
      end

      it "takes 11 samples from each end of 101" do
        expect(reading.first_instructions).to eq(200)
      end
    end
  end

  describe "the descriptive readings" do
    subject(:reading) do
      described_class.read(samples, parent_epoch: parent_epoch, descriptive: %w[steal_rate], bin: 1_000)
    end

    let(:samples) { own_samples { |index| values(share: index < 20 ? 0.2 : 0.8).merge("steal_rate" => 0.03) } }

    it "takes the last-decile median of each key" do
      expect(reading.last_median("steal_rate")).to eq(0.03)
    end

    it "bins the share by own epochs, keyed by each bin's last epoch" do
      expect(reading.shares_by_bin.first(2)).to eq([[1_000, 0.2], [2_000, 0.8]])
    end
  end
end
