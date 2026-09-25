# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::OrientedSummary do
  def reading(epoch, share, source = described_class::STORED)
    described_class::Reading.new(epoch: epoch, share: share, source: source)
  end

  def summary(*readings, epochs: 3_000) = described_class.new(epochs: epochs, readings: readings)

  context "with a run that took hold and kept it" do
    subject(:read) { summary(reading(0, 0.0), reading(1_000, 0.6), reading(2_000, 0.9), reading(3_000, 0.7)) }

    it "reads the share at the run's last epoch" do
      expect(read.terminal_share).to eq(0.7)
    end

    it "reads the peak and where it came" do
      expect([read.peak_share, read.peak_epoch]).to eq([0.9, 2_000])
    end

    it "reads the first reading at the qualifying share" do
      expect(read.first_replicator_epoch).to eq(1_000)
    end

    it "reads it as held" do
      expect(read.held).to be(true)
    end

    it "counts it a replicator world held to the end" do
      expect([read.replicator_world?, read.held_to_end?]).to eq([true, true])
    end
  end

  context "with a run that lost its replicators" do
    subject(:read) { summary(reading(1_000, 0.6), reading(2_000, 0.2), reading(3_000, 0.8)) }

    it "reads it as not held" do
      expect(read.held).to be(false)
    end
  end

  context "with a run that never reached the share" do
    subject(:read) { summary(reading(1_000, 0.1), reading(3_000, 0.4)) }

    it "has no first replicator epoch and nothing held" do
      expect([read.first_replicator_epoch, read.held, read.replicator_world?]).to eq([nil, nil, false])
    end
  end

  context "with a reading that lacks the share" do
    subject(:read) { summary(reading(1_000, 0.6), reading(2_000, nil), reading(3_000, nil)) }

    it "skips it rather than reading a zero" do
      expect([read.readings.size, read.held, read.terminal_share]).to eq([1, true, nil])
    end
  end

  context "with no readings" do
    subject(:read) { summary }

    it "is unmeasured with every reading blank" do
      expect([read.measured?, read.terminal_share, read.peak_share, read.first_replicator_epoch, read.held])
        .to eq([false, nil, nil, nil, nil])
    end
  end

  context "with both sources reading the same epoch" do
    subject(:read) do
      summary(reading(1_000, 0.2), reading(1_000, 0.8, described_class::LIVE), reading(2_000, 0.9))
    end

    it "keeps the live sample" do
      expect(read.readings.map(&:share)).to eq([0.8, 0.9])
    end

    it "counts each source apart" do
      expect([read.stored_count, read.live_count]).to eq([1, 1])
    end
  end
end
