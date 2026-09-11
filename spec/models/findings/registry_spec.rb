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

  it "leads a shared date with the strongest current result" do
    slugs = described_class.all.map(&:slug)

    expect(slugs.first(3)).to eq(%w[mutation-rate-long-horizon mutation-rate-window bff-control])
  end

  it "keeps the order of findings sharing a date fixed across calls" do
    same_date = %w[first second third].map do |slug|
      Findings::Finding.new(slug: slug, title: slug, date: Date.new(2026, 9, 11),
                            experiment_slug: "mutation-rate", status: :open, summary: slug,
                            body_partial: "findings/bodies/mutation_rate_window")
    end
    stub_const("Findings::Registry::ALL", same_date)

    expect(Array.new(3) { described_class.all.map(&:slug) })
      .to all(eq(%w[first second third]))
  end

  it "names a sweep the lab knows how to build" do
    known = Lab::SWEEPS.keys.map { |sweep| Lab.slug_for(sweep) }

    expect(described_class.all.map(&:experiment_slug)).to all(be_in(known))
  end

  it "ships the body partial every finding names" do
    described_class.all.to_a.each do |finding|
      directory, name = finding.body_partial.split("/").last(2)

      expect(Rails.root.join("app/views/findings", directory, "_#{name}.html.erb")).to exist
    end
  end

  it "renders the body partial every finding names" do
    described_class.all.to_a.each do |finding|
      expect(ApplicationController.render(partial: finding.body_partial)).to include("<h2>")
    end
  end

  it "leaves per-run facts out of the mutation-rate body" do
    body = ApplicationController.render(partial: described_class.find("mutation-rate-window").body_partial)

    expect(body).not_to match(/\d{2}:\d{2} CEST/)
    expect(body).not_to match(/run 41/i)
  end

  it "leaves lab timestamps out of every body" do
    described_class.all.to_a.each do |finding|
      expect(ApplicationController.render(partial: finding.body_partial)).not_to include("CEST")
    end
  end

  it "publishes the positive control the design record makes mandatory" do
    expect(described_class.find("bff-control").experiment_slug).to eq("bff-control")
  end

  it "holds the positive control at partial while its census peak cannot be rescored" do
    finding = described_class.find("bff-control")

    expect(finding.status).to eq(:partial)
    expect(finding.summary).to include("largest replicator census in the lab",
                                       "not yet resolved")
  end

  it "reads the long-horizon re-run as partial while three of its runs are still on the clock" do
    finding = described_class.find("mutation-rate-long-horizon")

    expect(finding).to have_attributes(experiment_slug: "mutation-rate-long", status: :partial)
    expect(finding.summary).to include("re-run for 60 000 epochs",
                                       "half of those transitions land after epoch 20 000",
                                       "2^-14 arm stays silent")
  end

  it "finds a finding by slug" do
    expect(described_class.find("mutation-rate-window").status).to eq(:partial)
  end

  it "reads the world-size sweep as partial while two of its runs resume" do
    finding = described_class.find("world-size-scaling")

    expect(finding).to have_attributes(experiment_slug: "world-size", status: :partial)
    expect(finding.summary).to include("emergence gets more likely as the world gets bigger",
                                       "2.5 × 10⁻¹⁰ per cell-epoch",
                                       "still resuming from their snapshots")
  end

  it "reads the finished radius sweep as a negative on the speed half of DESIGN 1.3 sweep 3" do
    finding = described_class.find("radius-locality")

    expect(finding).to have_attributes(experiment_slug: "radius", status: :negative)
    expect(finding.summary).to include("the well-mixed arm transitioned as often as the best local arm",
                                       "is not supported",
                                       "stays open")
  end

  it "returns nothing for an unknown slug" do
    expect(described_class.find("nope")).to be_nil
  end
end
