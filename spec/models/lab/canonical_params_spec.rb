# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::CanonicalParams do
  describe ".for" do
    it "fills in the engine defaults a stored run never carried" do
      stored = Lab::Schema.run_defaults.except("ops").merge("radius" => 2)

      expect(described_class.for(stored)).to eq(described_class.for(Lab::Schema.run_defaults.merge("radius" => 2)))
    end

    it "reads an integer and a float of the same value as one arm" do
      expect(described_class.for("radius" => 0)).to eq(described_class.for("radius" => 0.0))
    end

    it "ignores the order the keys were written in" do
      expect(described_class.for("radius" => 2, "width" => 32))
        .to eq(described_class.for("width" => 32, "radius" => 2))
    end

    it "keeps arms that differ apart" do
      expect(described_class.for("radius" => 2)).not_to eq(described_class.for("radius" => 4))
    end
  end

  describe ".same_value?" do
    it "matches a stored integer against its rake argument" do
      expect(described_class).to be_same_value(64, "64")
    end

    it "matches a stored float against a differently written argument" do
      expect(described_class).to be_same_value(0.0, "0")
    end

    it "matches a stored string exactly" do
      expect(described_class).to be_same_value("<>{}+-.,[]", "<>{}+-.,[]")
    end

    it "does not match a different number" do
      expect(described_class).not_to be_same_value(64, "0")
    end

    it "does not match a number against a word" do
      expect(described_class).not_to be_same_value(64, "sixty-four")
    end
  end
end
