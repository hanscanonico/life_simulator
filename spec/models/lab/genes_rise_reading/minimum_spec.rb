# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::GenesRiseReading::Minimum do
  it "rises late from the fifth-decile world to the last by a step and a fifth" do
    expect(described_class.new(fifth: 90, last: 108)).to be_late_rise
    expect(described_class.new(fifth: 0, last: 1)).to be_late_rise
  end

  it "reads no late rise on a gain under a fifth, under a step, or a fall" do
    expect(described_class.new(fifth: 90, last: 107)).not_to be_late_rise
    expect(described_class.new(fifth: 3, last: 3)).not_to be_late_rise
    expect(described_class.new(fifth: 50, last: 40)).not_to be_late_rise
  end

  it "is unread without both worlds' readings" do
    expect([described_class.none, described_class.new(fifth: 4, last: nil)].map(&:measured?)).to eq([false, false])
    expect(described_class.none).not_to be_late_rise
  end

  it "parses the offline tool's CSV by run id, a blank value unread" do
    minima = described_class.parse("run_id,fifth_minimum,last_minimum\n12,90,150\n13,4,\n")

    expect(minima).to eq(12 => described_class.new(fifth: 90, last: 150), 13 => described_class.new(fifth: 4, last: nil))
  end

  it "refuses a value that is not a whole number" do
    expect { described_class.parse("run_id,fifth_minimum,last_minimum\n12,9.5,150\n") }.to raise_error(ArgumentError)
  end
end
