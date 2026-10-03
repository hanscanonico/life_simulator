# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:thin_unemerged" do
  let(:experiment) { create(:experiment, slug: "radius") }
  let!(:run) do
    create(:run, experiment: experiment, status: "finished", epochs: 3_000).tap do |run|
      insert_snapshots(run, [0, 1_000, 2_000, 3_000])
      [0, 1_000, 2_000, 3_000].each do |epoch|
        create(:snapshot_reading, run: run, epoch: epoch, source_epoch: epoch)
      end
    end
  end

  def kept = run.snapshots.order(:epoch).pluck(:epoch)

  around do |example|
    keys = %w[CONFIRM DRY_RUN MAX_RUNS TIME_LIMIT]
    saved = ENV.to_h.slice(*keys)
    keys.each { |key| ENV.delete(key) }
    example.run
  ensure
    keys.each { |key| ENV.delete(key) }
    ENV.update(saved)
  end

  context "without CONFIRM" do
    it "prints what it would delete and deletes nothing" do
      output = invoke("lab:thin_unemerged")

      expect([kept, output]).to eq([[0, 1_000, 2_000, 3_000],
                                    "radius: 1 runs, 2 snapshots, 40 Bytes\n" \
                                    "would delete 2 snapshots of 1 runs, 40 Bytes (40 bytes)\n" \
                                    "dry run: CONFIRM=yes deletes\n"])
    end
  end

  context "with CONFIRM=yes" do
    it "deletes the intermediate worlds and points to the vacuum" do
      ENV["CONFIRM"] = "yes"

      output = invoke("lab:thin_unemerged")

      expect([kept, output.lines.last]).to eq([[0, 3_000], "then run lab:vacuum_snapshots (a plain VACUUM (ANALYZE) " \
                                                           "snapshots) so Postgres reuses the space\n"])
    end
  end

  context "with CONFIRM=yes and DRY_RUN=1" do
    it "deletes nothing" do
      ENV["CONFIRM"] = "yes"
      ENV["DRY_RUN"] = "1"

      invoke("lab:thin_unemerged")

      expect(kept).to eq([0, 1_000, 2_000, 3_000])
    end
  end

  context "with CONFIRM=yes and DRY_RUN=true" do
    it "deletes nothing" do
      ENV["CONFIRM"] = "yes"
      ENV["DRY_RUN"] = "true"

      invoke("lab:thin_unemerged")

      expect(kept).to eq([0, 1_000, 2_000, 3_000])
    end
  end

  context "with a limit that is not a positive number" do
    it "refuses before deleting anything" do
      ENV["CONFIRM"] = "yes"
      ENV["MAX_RUNS"] = "0"

      expect { invoke("lab:thin_unemerged") }.to raise_error(RuntimeError, /must be positive/)
      expect(kept).to eq([0, 1_000, 2_000, 3_000])
    end

    it "refuses a TIME_LIMIT it cannot read" do
      ENV["CONFIRM"] = "yes"
      ENV["TIME_LIMIT"] = "15m"

      expect { invoke("lab:thin_unemerged") }.to raise_error(ArgumentError)
      expect(kept).to eq([0, 1_000, 2_000, 3_000])
    end
  end

  context "with MAX_RUNS reached" do
    it "says to run it again" do
      other = create(:run, experiment: experiment, status: "finished", epochs: 2_000)
      insert_snapshots(other, [0, 1_000, 2_000])
      create(:snapshot_reading, run: other, epoch: 1_000, source_epoch: 1_000)
      ENV["MAX_RUNS"] = "1"

      expect(invoke("lab:thin_unemerged")).to include("stopped at the batch limit: run it again to continue")
    end
  end

  describe "lab:vacuum_snapshots" do
    it "runs a plain VACUUM (ANALYZE) on snapshots" do
      connection = ActiveRecord::Base.connection
      allow(connection).to receive(:execute).and_call_original
      allow(connection).to receive(:execute).with("VACUUM (ANALYZE) snapshots")

      invoke("lab:vacuum_snapshots")

      expect(connection).to have_received(:execute).with("VACUUM (ANALYZE) snapshots")
    end
  end

  def invoke(name, *args)
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    task = Rake::Task[name]
    task.reenable
    original = $stdout
    $stdout = StringIO.new
    task.invoke(*args)
    $stdout.string
  ensure
    $stdout = original
  end
end
