# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::ToplessRiseReading::Child do
  # 200 own samples 10 epochs apart from the parent epoch 1 000: the last 100 are settled, so
  # the fifth decile is indices 140–149, the sixth starts at 150 (epoch 2 510) and the last
  # decile is 190–199.
  def read(depths)
    samples = Array.new(200) { |index| [1_000 + (10 * (index + 1)), { "logic_depth_max" => depths.call(index) }] }
    described_class.read(samples, parent_epoch: 1_000)
  end

  def steps(fifth, last) = ->(index) { index >= 190 ? last : fifth }

  it "rises late at one step above the fifth decile, and not short of it" do
    expect([read(steps(9, 10)), read(steps(9, 9)), read(steps(9, 8))].map(&:rises?)).to eq([true, false, false])
  end

  it "reads the fifth decile as its own tenth of the settled samples, not the first half" do
    reading = read(->(index) { index.between?(140, 149) ? 4 : 9 })

    expect(reading).to have_attributes(fifth_depth: 4, last_depth: 9, first_half_held: 9, bar: 9)
  end

  describe "the bar a late rise must clear" do
    it "does not rise back to a depth held before the second half after a dip at the fifth decile" do
      expect(read(->(index) { index.between?(140, 149) ? 4 : 9 })).not_to be_rises
    end

    it "does not rise back to the parent's depth at descent, held for fewer samples than persistence asks" do
      reading = read(->(index) { index.zero? || index >= 190 ? 5 : 2 })

      expect(reading).to have_attributes(descent_depth: 5, first_half_held: 2, fifth_depth: 2, bar: 5)
      expect(reading).not_to be_rises
    end

    it "rises past the parent's depth at descent" do
      reading = read(->(index) { [5, *Array.new(189, 2), *Array.new(10, 6)][index] })

      expect(reading).to be_rises
    end

    it "does not rise to a depth held five samples running in the settling window and lost" do
      reading = read(->(index) { index.between?(3, 7) || index >= 190 ? 11 : 9 })

      expect(reading).to have_attributes(first_half_held: 11, fifth_depth: 9, bar: 11)
      expect(reading).not_to be_rises
    end

    it "rises to a depth held four samples running before the second half" do
      reading = read(->(index) { index.between?(3, 6) || index >= 190 ? 11 : 9 })

      expect(reading).to have_attributes(first_half_held: 9, bar: 9)
      expect(reading).to be_rises
    end

    it "sets no bar by a run of five that ends past the fifth decile" do
      reading = read(->(index) { index.between?(147, 151) || index >= 190 ? 11 : 9 })

      expect(reading).to have_attributes(first_half_held: 9, bar: 9)
      expect(reading).to be_rises
    end
  end

  it "takes the lower middle of an even decile" do
    expect(read(->(index) { index.between?(190, 194) ? 6 : 9 }).last_depth).to eq(6)
  end

  context "with nothing held" do
    it "enters −1 into a median as a number below ECHO's 0" do
      reading = read(->(index) { index >= 190 && index.even? ? 0 : -1 })

      expect(reading).to have_attributes(fifth_depth: -1, last_depth: -1)
      expect(reading).not_to be_rises
    end

    it "rises from nothing held, at descent and since, to ECHO" do
      expect(read(steps(-1, 0))).to have_attributes(descent_depth: -1, first_half_held: nil, bar: -1, rises?: true)
    end

    it "does not rise back to ECHO where the parent held it at descent" do
      reading = read(->(index) { index.zero? || index >= 190 ? 0 : -1 })

      expect(reading).to have_attributes(descent_depth: 0, bar: 0)
      expect(reading).not_to be_rises
    end

    it "holds no depth" do
      expect(read(->(_) { -1 })).to have_attributes(deepest_held: -1, deepest_held_epoch: nil, late_depths: [])
    end
  end

  context "with a decile short of numbers" do
    it "is unmeasured and never rises" do
      reading = read(->(index) { index.between?(141, 149) ? nil : 9 })

      expect(reading).to have_attributes(fifth_depth: nil, measured?: false, rises?: false, ceilinged?: false)
    end
  end

  context "with the fifth decile already at the 13 floor" do
    it "is ceilinged, read as no rise, and reached the floor" do
      reading = read(steps(13, 13))

      expect(reading).to have_attributes(ceilinged?: true, rises?: false, reached_floor: true)
    end
  end

  context "with the 13 floor held before the second half and lost by the fifth decile" do
    it "is ceilinged" do
      reading = read(->(index) { index.between?(20, 24) ? 13 : 9 })

      expect(reading).to have_attributes(fifth_depth: 9, bar: 13, ceilinged?: true, rises?: false)
    end
  end

  it "reads one sample at 13 as reaching the floor without ceilinging" do
    reading = read(->(index) { index == 20 ? 13 : 9 })

    expect(reading).to have_attributes(reached_floor: true, ceilinged?: false)
  end

  describe "another key" do
    def read_classes(classes, ceiling: nil)
      samples = Array.new(200) do |index|
        [1_000 + (10 * (index + 1)), { "logic_depth_max" => 2, "logic_depth_classes" => classes.call(index) }]
      end
      described_class.read(samples, parent_epoch: 1_000, key: "logic_depth_classes", ceiling: ceiling)
    end

    it "runs the same rule on it, depth aside" do
      reading = read_classes(steps(14, 16))

      expect(reading).to have_attributes(fifth_depth: 14, last_depth: 16, descent_depth: 14, bar: 14, rises?: true)
      expect(reading.late_depths).to eq([15, 16])
    end

    it "reads no ceiling and no floor where it is given none" do
      expect(read_classes(steps(13, 20))).to have_attributes(ceilinged?: false, reached_floor: false, rises?: true)
    end

    it "ceilings at the ceiling it is given" do
      expect(read_classes(steps(13, 20), ceiling: 13)).to have_attributes(ceilinged?: true, rises?: false)
    end
  end

  describe "first epochs" do
    it "needs five samples running at a depth or deeper" do
      reading = read(->(index) { index.between?(10, 13) || index >= 160 ? 11 : 9 })

      expect(reading.deepest_held).to eq(11)
      expect(reading.deepest_held_epoch).to eq(1_000 + (10 * 161))
    end

    it "lists the depths first held in the second half of the settled samples" do
      reading = read(->(index) { index >= 170 ? 12 : 9 })

      expect(reading.late_depths).to eq([10, 11, 12])
    end

    it "lists no depth first held before the second half, even after a loss" do
      reading = read(->(index) { index.between?(60, 120) || index >= 170 ? 12 : 9 })

      expect(reading.late_depths).to eq([])
    end
  end
end
