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

    expect(slugs.first(3)).to eq(%w[mutation-rate-window bff-control world-size-scaling])
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

  it "publishes the positive control the design record makes mandatory" do
    expect(described_class.find("bff-control").experiment_slug).to eq("bff-control")
  end

  it "holds the positive control at partial while its census is unresolved" do
    finding = described_class.find("bff-control")

    expect(finding.status).to eq(:partial)
    expect(finding.summary).to include("one mutated seed of three", "census unresolved")
  end

  it "finds a finding by slug" do
    expect(described_class.find("mutation-rate-window").status).to eq(:partial)
  end

  it "opens the world-size sweep against DESIGN 1.3 sweep 2" do
    expect(described_class.find("world-size-scaling"))
      .to have_attributes(experiment_slug: "world-size", status: :open)
  end

  it "returns nothing for an unknown slug" do
    expect(described_class.find("nope")).to be_nil
  end
end
