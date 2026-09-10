# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::ReleaseStaleJob do
  it "returns a silent run to the queue" do
    run = create(:run, :stale)

    described_class.perform_now

    expect(run.reload).to have_attributes(status: "pending", runner_id: nil)
  end

  it "reports how many runs it released" do
    create(:run, :stale)

    expect(described_class.perform_now).to eq(1)
  end

  it "leaves a run that is still heartbeating alone" do
    run = create(:run, :claimed)

    described_class.perform_now

    expect(run.reload.status).to eq("claimed")
  end
end
