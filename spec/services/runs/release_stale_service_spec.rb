# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::ReleaseStaleService do
  it "returns a silent run to the queue" do
    run = create(:run, :stale)

    described_class.call

    expect(run.reload).to have_attributes(status: "pending", runner_id: nil, claimed_at: nil, heartbeat_at: nil)
  end

  it "keeps the progress the runner already reported" do
    run = create(:run, :stale, epochs_done: 1_200)

    described_class.call

    expect(run.reload.epochs_done).to eq(1_200)
  end

  it "leaves a run that is still heartbeating alone" do
    run = create(:run, :claimed)

    described_class.call

    expect(run.reload.status).to eq("claimed")
  end

  it "reports how many runs it released" do
    create(:run, :stale)

    expect(described_class.call).to eq(1)
  end

  it "releases the whole batch in one statement, since every claim poll calls it" do
    create_list(:run, 3, :stale)
    updates = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      updates << payload[:sql] if payload[:sql].start_with?("UPDATE")
    end

    described_class.call
    ActiveSupport::Notifications.unsubscribe(subscription)

    expect(updates.size).to eq(1)
  end
end
