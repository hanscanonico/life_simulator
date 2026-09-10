# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::Registry do
  it "publishes at least one finding" do
    expect(described_class.all).to be_present
  end

  it "gives every finding its own slug" do
    slugs = described_class.all.map(&:slug)

    expect(slugs.uniq).to eq(slugs)
  end

  it "orders the log newest first" do
    dates = described_class.all.map(&:date)

    expect(dates).to eq(dates.sort.reverse)
  end

  it "names a sweep the lab knows how to build" do
    known = Lab::SWEEPS.keys.map { |sweep| sweep.tr("_", "-") }

    expect(described_class.all.map(&:experiment_slug)).to all(be_in(known))
  end

  it "ships the body partial every finding names" do
    described_class.all.to_a.each do |finding|
      directory, name = finding.body_partial.split("/").last(2)

      expect(Rails.root.join("app/views/findings", directory, "_#{name}.html.erb")).to exist
    end
  end

  it "finds a finding by slug" do
    expect(described_class.find("mutation-rate-window").status).to eq(:open)
  end

  it "returns nothing for an unknown slug" do
    expect(described_class.find("nope")).to be_nil
  end
end
