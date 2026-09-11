# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::ClaimService do
  subject(:claim) { described_class.call(runner_id: "runner-1") }

  it "hands out the oldest pending run" do
    oldest = create(:run)
    create(:run)

    expect(claim).to eq(oldest)
  end

  it "hands out the highest priority pending run first" do
    create(:run)
    urgent = create(:run, priority: 5)

    expect(claim).to eq(urgent)
  end

  it "hands out the oldest run of the highest priority" do
    oldest_urgent = create(:run, priority: 5)
    create(:run, priority: 5)

    expect(claim).to eq(oldest_urgent)
  end

  it "marks the run claimed by the calling runner" do
    create(:run)

    expect(claim).to have_attributes(status: "claimed", runner_id: "runner-1")
  end

  it "stamps the claim so the stale sweeper can find it later" do
    create(:run)

    expect(claim.heartbeat_at).to be_present
  end

  it "moves the experiment out of the queue" do
    run = create(:run, experiment: create(:experiment, status: "queued"))

    claim

    expect(run.experiment.reload).to be_running
  end

  it "locks the row it claims so two runners cannot take it at once" do
    create(:run)
    statements = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql]
    end

    claim
    ActiveSupport::Notifications.unsubscribe(subscription)

    expect(statements).to include(a_string_including("FOR UPDATE SKIP LOCKED"))
  end

  it "picks up a run whose runner went silent" do
    stale = create(:run, :stale)

    expect(claim).to eq(stale)
  end

  it "logs the claim for the runner log" do
    run = create(:run)
    allow(Rails.logger).to receive(:info)

    claim

    expect(Rails.logger).to have_received(:info).with(/event=run_claimed run_id=#{run.id} runner_id="runner-1"/)
  end

  context "with an empty queue" do
    it "returns nothing" do
      create(:run, :claimed)

      expect(claim).to be_nil
    end
  end
end
