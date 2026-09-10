# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::Finding do
  subject(:finding) do
    described_class.new(slug: "mutation-rate-window", title: "A window?", date: Date.new(2026, 9, 10),
                        experiment_slug: "mutation-rate", status: :open, summary: "Running.")
  end

  it "is addressed by slug" do
    expect(finding.to_param).to eq("mutation-rate-window")
  end

  it "derives the body partial from the slug" do
    expect(finding.body_partial).to eq("findings/bodies/mutation_rate_window")
  end

  it "colours the badge by status" do
    expect(finding.badge_class).to eq("badge-info")
  end

  context "with an unknown status" do
    it "refuses to exist" do
      build = lambda do
        described_class.new(slug: "x", title: "x", date: Date.new(2026, 9, 10), experiment_slug: "x",
                            status: :maybe, summary: "x")
      end

      expect(&build).to raise_error(ArgumentError, /maybe/)
    end
  end
end
