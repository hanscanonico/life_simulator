# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#percent_value" do
    it "reads a fraction as a whole percent" do
      expect(helper.percent_value(0.5)).to eq("50%")
    end

    it "rounds to the nearest percent" do
      expect(helper.percent_value(0.126)).to eq("13%")
    end

    context "with no fraction" do
      it "is a dash" do
        expect(helper.percent_value(nil)).to eq("—")
      end
    end
  end

  describe "#epoch_value" do
    it "delimits one epoch" do
      expect(helper.epoch_value(20_000)).to eq("20,000")
    end

    it "collapses a pair of equal epochs" do
      expect(helper.epoch_value(400, 400)).to eq("400")
    end

    it "joins a quartile pair with a dash" do
      expect(helper.epoch_value(200.0, 550.0)).to eq("200–550")
    end

    context "with a missing end" do
      it "is a dash" do
        expect(helper.epoch_value(400, nil)).to eq("—")
      end
    end
  end
end
