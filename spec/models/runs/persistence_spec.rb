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
end
