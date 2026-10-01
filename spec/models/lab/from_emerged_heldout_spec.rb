# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::FromEmergedHeldout do
  describe ".held_out?" do
    def parent(id:, seed:) = Run.new(id: id, seed: seed)

    it "holds out an extension parent none of whose children were seen" do
      expect(described_class.held_out?(parent(id: 3_000, seed: 91))).to be(true)
    end

    it "does not hold out a parent of the first ninety seeds" do
      expect(described_class.held_out?(parent(id: 3_000, seed: 90))).to be(false)
    end

    it "does not hold out run 2568, an extension parent whose children were seen" do
      expect(described_class.held_out?(parent(id: 2_568, seed: 102))).to be(false)
    end
  end
end
