# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::TransitionRate do
  describe "#fraction" do
    it "is the share of the finished runs that transitioned" do
      expect(described_class.new(transitioned: 1, finished: 2).fraction).to eq(0.5)
    end

    context "when no finished run transitioned" do
      it "is zero" do
        expect(described_class.new(transitioned: 0, finished: 3).fraction).to eq(0.0)
      end
    end

    context "with no finished run" do
      it "has no value rather than zero" do
        expect(described_class.new(transitioned: 0, finished: 0).fraction).to be_nil
      end
    end
  end
end
