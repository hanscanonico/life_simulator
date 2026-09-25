# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::OrientedSummariesService do
  let(:experiment) { create(:experiment) }
  let(:stored) { create(:run, experiment: experiment, epochs: 2_000, status: "finished") }
  let(:live) { create(:run, experiment: experiment, epochs: 2_000, status: "finished") }
  let(:unread) { create(:run, experiment: experiment, epochs: 2_000, status: "finished") }

  let(:summaries) { described_class.call(runs: [stored, live, unread]) }

  def read(run, epoch, share, source_epoch: epoch, instrument: "oriented_census/1")
    create(:snapshot_reading, run: run, instrument: instrument, epoch: epoch, source_epoch: source_epoch,
                              values: { "replicator_share" => share })
  end

  before do
    read(stored, 1_000, 0.6)
    read(stored, 2_000, 0.75)
    read(stored, 1_500, 0.1, instrument: "other_census/1")
    create(:sample, run: live, epoch: 2_000, values: { "compress_ratio" => 0.4, "replicator_share" => 0.625 })
    create(:sample, run: unread, epoch: 2_000, values: { "compress_ratio" => 0.9 })
  end

  context "with a run read from its stored worlds" do
    it "summarises the instrument's static readings" do
      summary = summaries.fetch(stored.id)

      expect([summary.readings.size, summary.terminal_share, summary.first_replicator_epoch, summary.held])
        .to eq([2, 0.75, 1_000, true])
    end
  end

  context "with a reading stepped on from a stored world" do
    it "leaves out the in-situ reading after the world" do
      read(stored, 1_010, 0.9, source_epoch: 1_000)

      expect(summaries.fetch(stored.id).peak_share).to eq(0.75)
    end

    it "leaves out the reading past the run's last epoch" do
      read(unread, 2_010, 0.9, source_epoch: 2_000)

      expect(summaries.fetch(unread.id)).not_to be_measured
    end
  end

  context "with a run only its live samples read" do
    it "is unmeasured" do
      expect(summaries.fetch(live.id)).not_to be_measured
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

  it "costs one query whatever the runs" do
    runs = [stored, live, unread]
    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.call(runs: runs) }

    expect(queries).to eq(1)
  end
end
