# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::Persistence do
  describe ".from" do
    it "reads a stored summary" do
      persistence = described_class.from("census_peak" => 123, "peak_epoch" => 5_080,
                                         "epochs_persisted" => 7_000, "relapsed" => false)

      expect(persistence).to have_attributes(census_peak: 123, peak_epoch: 5_080, epochs_persisted: 7_000)
      expect(persistence).not_to be_relapsed
      expect(persistence).to be_counted
    end

    it "reads a summary that has not been through the jsonb column yet" do
      persistence = described_class.from(census_peak: 12, peak_epoch: 80, epochs_persisted: 900,
                                         relapsed: true)

      expect(persistence).to have_attributes(census_peak: 12, peak_epoch: 80, epochs_persisted: 900)
      expect(persistence).to be_relapsed
    end

    it "is nothing for a run with no summary" do
      expect(described_class.from({})).to be_nil
      expect(described_class.from(nil)).to be_nil
    end
  end

  describe "#counted?" do
    it "is false for a census that never left zero" do
      expect(described_class.new(census_peak: 0, peak_epoch: nil, epochs_persisted: 40, relapsed: true))
        .not_to be_counted
    end
  end

  describe "#sampled?" do
    it "tells a census that read zero from samples that carried no census at all" do
      zero = described_class.new(census_peak: 0, peak_epoch: nil, epochs_persisted: 40, relapsed: true)
      missing = described_class.new(census_peak: nil, peak_epoch: nil, epochs_persisted: 40, relapsed: true)

      expect(zero).to be_sampled
      expect(missing).not_to be_sampled
    end
  end
  describe ".exit_confirmable?" do
    it "needs as many samples from the crossing onwards as an exit takes" do
      expect(described_class.exit_confirmable?(described_class::EXIT_SAMPLES)).to be(true)
    end

    it "reads a shorter series as having no room for an exit" do
      expect(described_class.exit_confirmable?(described_class::EXIT_SAMPLES - 1)).to be(false)
    end
  end

  describe ".none" do
    it "answers every reading absent and no outcome either way" do
      none = described_class.none

      expect(none).to have_attributes(summarised?: false, relapsed?: false, persisted?: false,
                                      counted?: false, sampled?: false, census_peak: nil,
                                      peak_epoch: nil, epochs_persisted: nil)
      expect(none.census_label).to eq("—")
    end
  end

  describe "#census_label" do
    it "tells a census never taken from one that read zero" do
      missing = described_class.new(census_peak: nil, peak_epoch: nil, epochs_persisted: 40, relapsed: false)
      zero = described_class.new(census_peak: 0, peak_epoch: nil, epochs_persisted: 40, relapsed: false)
      counted = described_class.new(census_peak: 1_234, peak_epoch: 80, epochs_persisted: 40, relapsed: false)

      expect(missing.census_label).to eq("— (not sampled)")
      expect(zero.census_label).to eq("0 (no replicator counted)")
      expect(counted.census_label).to eq("1,234")
    end

    it "drops the gloss in a table cell, where the column says what it is" do
      zero = described_class.new(census_peak: 0, peak_epoch: nil, epochs_persisted: 40, relapsed: false)
      counted = described_class.new(census_peak: 1_234.0, peak_epoch: 80, epochs_persisted: 40, relapsed: false)

      expect(zero.compact_census_label).to eq("0")
      expect(counted.compact_census_label).to eq("1,234")
    end
  end
end
