# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::StatusPage do
  subject(:page) { described_class.build }

  describe "#counts_by_status" do
    it "counts every status, including the empty ones" do
      create(:run)
      create(:run, :claimed)

      expect(page.counts_by_status).to eq("pending" => 1, "claimed" => 1, "running" => 0,
                                          "finished" => 0, "failed" => 0)
    end

    it "totals the runs" do
      create_list(:run, 2)

      expect(page.total_runs).to eq(2)
    end
  end

  describe "#runners" do
    it "reports a runner that heartbeated inside the window" do
      create(:run, :claimed, runner_id: "runner-a", epochs_done: 120)
      create(:run, :claimed, runner_id: "runner-a", epochs_done: 80)

      expect(page.runners.sole).to have_attributes(id: "runner-a", runs: 2, epochs_done: 200)
    end

    context "with a runner silent for more than five minutes" do
      it "leaves it out" do
        create(:run, :stale, runner_id: "runner-b")

        expect(page.runners).to be_empty
      end
    end
  end

  describe "#epochs_per_hour" do
    it "sums the epochs each run covered inside the window" do
      run = create(:run, :claimed)
      create(:sample, run: run, epoch: 100)
      create(:sample, run: run, epoch: 900)

      expect(page.epochs_per_hour).to eq(800)
    end

    context "with samples older than the window" do
      it "ignores them" do
        run = create(:run, :claimed)
        create(:sample, run: run, epoch: 100, created_at: 3.hours.ago)
        create(:sample, run: run, epoch: 900, created_at: 3.hours.ago)

        expect(page.epochs_per_hour).to eq(0)
      end
    end
  end

  describe "#oldest_pending" do
    it "is the run at the head of the queue" do
      oldest = create(:run, created_at: 2.days.ago)
      create(:run)

      expect(page.oldest_pending).to eq(oldest)
    end

    context "with an empty queue" do
      it "has no run to point at" do
        create(:run, :claimed)

        expect(page.oldest_pending).to be_nil
      end
    end
  end
end
