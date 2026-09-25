# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::OrientedSummariesService do
  let(:experiment) { create(:experiment) }
  let(:stored) { create(:run, experiment: experiment, epochs: 2_000, status: "finished") }
  let(:live) { create(:run, experiment: experiment, epochs: 2_000, status: "finished") }
  let(:unread) { create(:run, experiment: experiment, epochs: 2_000, status: "finished") }

  let(:summaries) { described_class.call(runs: [stored, live, unread]) }

  before do
    create(:snapshot_reading, run: stored, epoch: 1_000, source_epoch: 1_000, values: { "replicator_share" => 0.6 })
    create(:snapshot_reading, run: stored, epoch: 2_000, source_epoch: 2_000, values: { "replicator_share" => 0.75 })
    create(:snapshot_reading, run: stored, instrument: "other_census/1", epoch: 1_500, source_epoch: 1_500,
                              values: { "replicator_share" => 0.1 })
    create(:sample, run: live, epoch: 1_990, values: { "compress_ratio" => 0.4, "replicator_share" => 0.5 })
    create(:sample, run: live, epoch: 2_000, values: { "compress_ratio" => 0.4, "replicator_share" => 0.625 })
    create(:sample, run: live, epoch: 1_000, values: { "compress_ratio" => 0.9 })
    create(:sample, run: unread, epoch: 2_000, values: { "compress_ratio" => 0.9 })
  end

  context "with a run read only from its stored worlds" do
    it "summarises the instrument's readings" do
      summary = summaries.fetch(stored.id)

      expect([summary.stored_count, summary.live_count, summary.terminal_share, summary.first_replicator_epoch])
        .to eq([2, 0, 0.75, 1_000])
    end
  end

  context "with a run read only from its live samples" do
    it "summarises the samples that carry the share" do
      summary = summaries.fetch(live.id)

      expect([summary.stored_count, summary.live_count, summary.terminal_share, summary.first_replicator_epoch])
        .to eq([0, 2, 0.625, 1_990])
    end
  end

  context "with a run nothing has read" do
    it "is unmeasured rather than a zero" do
      summary = summaries.fetch(unread.id)

      expect([summary.measured?, summary.peak_share, summary.terminal_share]).to eq([false, nil, nil])
    end
  end

  context "with a stored reading that lacks the share" do
    it "is no reading" do
      create(:snapshot_reading, run: unread, epoch: 1_000, source_epoch: 1_000, values: { "copy_rate" => 0.1 })

      expect(summaries.fetch(unread.id)).not_to be_measured
    end
  end

  it "costs two queries whatever the runs" do
    runs = [stored, live, unread]
    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.call(runs: runs) }

    expect(queries).to eq(2)
  end
end
