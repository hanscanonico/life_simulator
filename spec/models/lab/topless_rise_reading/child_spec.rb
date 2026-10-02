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

    expect(reading).to have_attributes(fifth_depth: 4, last_depth: 9)
    expect(reading).to be_rises
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

    it "rises from nothing held to ECHO" do
      expect(read(steps(-1, 0))).to be_rises
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

  it "reads one sample at 13 as reaching the floor without ceilinging" do
    reading = read(->(index) { index == 20 ? 13 : 9 })

    expect(reading).to have_attributes(reached_floor: true, ceilinged?: false)
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
