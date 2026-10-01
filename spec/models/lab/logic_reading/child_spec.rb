# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::LogicReading::Child do
  # `count` samples 10 epochs apart from the parent epoch 0; the settling window ends at 1 000.
  def samples(count, &values) = Array.new(count) { |index| [10 * (index + 1), values.call(index)] }

  def read(series) = described_class.read(series, parent_epoch: 0)

  it "reads the capabilities over the last decile of the settled samples only" do
    series = samples(300) do |index|
      { "logic_capability" => index >= 270 ? 4 : 1, "logic_capability_deep" => index >= 270 ? 1 : 0 }
    end

    expect(read(series).capabilities).to eq("logic_capability" => 4, "logic_capability_deep" => 1)
  end

  context "with fewer than ten numbers in the last decile" do
    it "leaves the capability unmeasured" do
      series = samples(200) { |index| { "logic_capability_deep" => index >= 191 ? 1 : nil } }

      expect(read(series).capability("logic_capability_deep")).to be_nil
    end
  end

  describe "the persistence rule" do
    it "reads a rung at the first of five samples running at a tenth, settling window included" do
      series = samples(200) { |index| { "logic_share_or" => index >= 4 ? 0.1 : 0.09 } }

      expect(read(series).first_epochs).to include("or" => 50, "nor" => nil)
    end

    it "ignores a rung that trips the line on fewer than five samples running" do
      series = samples(200) { |index| { "logic_share_xor" => (index % 5).zero? || index % 5 == 1 ? 0.2 : 0.0 } }

      expect(read(series)).to have_attributes(climbed_deep?: false)
      expect(read(series).first_epochs["xor"]).to be_nil
    end

    it "starts the run again after a sample that does not carry the share" do
      series = samples(200) do |index|
        share = if index == 13 then nil
                elsif index >= 10 then 0.3
                else 0.0
                end
        { "logic_share_equ" => share }
      end

      expect(read(series).first_epochs["equ"]).to eq(150)
    end
  end

  context "with a deep rung and no stepping stone before it" do
    it "reads the climb without a stepping stone" do
      series = samples(200) do |index|
        { "logic_share_xor" => index >= 10 ? 0.2 : 0.0, "logic_share_nor" => index >= 20 ? 0.2 : 0.0,
          "logic_share_orn" => 0.5 }
      end

      expect(read(series)).to have_attributes(deep_epoch: 110, climbed_deep?: true, stepping_stone?: false)
    end
  end

  context "with a stepping stone reached on the deep rung's own sample" do
    it "counts it as held before the climb" do
      series = samples(200) do |index|
        { "logic_share_equ" => index >= 10 ? 0.2 : 0.0, "logic_share_andn" => index >= 10 ? 0.2 : 0.0 }
      end

      expect(read(series)).to have_attributes(deep_epoch: 110, stepping_stone?: true)
    end
  end

  it "takes the commonest dominant logic mask of the last decile, the smaller on a tie" do
    series = samples(200) { |index| { "dominant_logic_tasks" => index.even? ? 7 : 3 } }

    expect(read(series).dominant_tasks).to eq(3)
  end
end
