# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::InstrumentNotes do
  it "notes only findings the registry publishes" do
    expect(described_class::NOTES.keys - Findings::Registry.all.map(&:slug)).to be_empty
  end

  it "points at the census issue" do
    expect(described_class::ISSUE_URL).to end_with("/issues/245")
  end

  it "keeps every note to a few sentences" do
    sentence_counts = described_class::NOTES.values.map { |note| note.scan(/[.?!](?:\s|\z)/).size }

    expect(sentence_counts).to all(be_between(2, 4))
  end

  it "reads a noted finding's note off the finding" do
    finding = Findings::Registry.find("emergence-can-be-left")

    expect(finding.instrument_note).to eq(described_class::NOTES.fetch("emergence-can-be-left"))
  end

  context "with a finding whose claims the census does not touch" do
    it "carries no note" do
      finding = Findings::Registry.find("radius-locality")

      expect(finding.instrument_note?).to be(false)
    end
  end
end
