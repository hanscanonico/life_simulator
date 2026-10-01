# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::MetabolismReading::Child do
  # `count` samples 10 epochs apart from the parent epoch 0; the settling window ends at 1 000.
  def samples(count, &values) = Array.new(count) { |index| [10 * (index + 1), values.call(index)] }

  def read(series) = described_class.read(series, parent_epoch: 0)

  it "reads the capabilities over the last decile of the settled samples only" do
    series = samples(300) { |index| { "task_capability" => index >= 270 ? 4 : 1, "task_capability_loop" => 0 } }

    expect(read(series).capabilities).to eq("task_capability" => 4, "task_capability_loop" => 0)
  end

  it "takes the lower middle of an even decile" do
    series = samples(200) { |index| { "task_capability" => index >= 195 ? 3 : 2 } }

    expect(read(series).capability("task_capability")).to eq(2)
  end

  context "with fewer than ten numbers in the last decile" do
    it "leaves the capability unmeasured" do
      series = samples(200) { |index| { "task_capability" => index >= 191 ? 3 : nil } }

      expect(read(series).capability("task_capability")).to be_nil
    end
  end

  it "reads the first epoch at which each task reaches a tenth, settling window included" do
    series = samples(200) { |index| { "task_share_echo" => index >= 4 ? 0.1 : 0.09 } }

    expect(read(series).first_epochs).to include("echo" => 50, "inc" => nil)
  end

  context "with a loop rung and no stepping stone before it" do
    it "reads the climb without a stepping stone" do
      series = samples(200) do |index|
        { "task_share_sub" => index >= 10 ? 0.2 : 0.0, "task_share_dec" => index >= 20 ? 0.2 : 0.0 }
      end

      expect(read(series)).to have_attributes(loop_epoch: 110, climbed_loop?: true, stepping_stone?: false)
    end
  end

  context "with a stepping stone reached on the loop rung's own sample" do
    it "counts it as held before the climb" do
      series = samples(200) do |index|
        { "task_share_add" => index >= 10 ? 0.2 : 0.0, "task_share_inc" => index >= 10 ? 0.2 : 0.0 }
      end

      expect(read(series)).to have_attributes(loop_epoch: 110, stepping_stone?: true)
    end
  end

  it "takes the commonest dominant task mask of the last decile, the smaller on a tie" do
    series = samples(200) { |index| { "dominant_tasks" => index.even? ? 7 : 3 } }

    expect(read(series).dominant_tasks).to eq(3)
  end
end
