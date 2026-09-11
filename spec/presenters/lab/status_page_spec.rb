# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::StatusPage do
  subject(:page) { described_class.build }

  def queries_during(&reading)
    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &reading)
    queries
  end

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
      first = create(:run, :claimed, runner_id: "runner-a", epochs_done: 120)
      second = create(:run, :claimed, runner_id: "runner-a", epochs_done: 80)

      expect(page.runners.sole).to have_attributes(id: "runner-a", epochs_done: 200,
                                                   run_ids: [first.id, second.id])
    end

    it "gives each slot the epochs its own runs covered in the last hour" do
      run = create(:run, :claimed, runner_id: "runner-a")
      other = create(:run, :claimed, runner_id: "runner-b")
      create(:sample, run: run, epoch: 100)
      create(:sample, run: run, epoch: 400)
      create(:sample, run: other, epoch: 0)
      create(:sample, run: other, epoch: 50)

      expect(page.runners.map(&:epochs_per_hour)).to eq([300, 50])
      expect(page.runners.sum(&:epochs_per_hour)).to eq(page.epochs_per_hour)
    end

    it "reads the hourly epochs once for the slots and the total alike" do
      run = create(:run, :claimed, runner_id: "runner-a")
      create(:sample, run: run, epoch: 100)

      expect(queries_during { page.runners && page.epochs_per_hour }).to eq(2)
    end

    it "costs the same two reads however many slots are busy" do
      12.times do |slot|
        run = create(:run, :claimed, runner_id: "runner-#{slot}")
        create(:sample, run: run, epoch: 0)
        create(:sample, run: run, epoch: 250)
      end

      expect(queries_during { page.runners.each(&:epochs_per_hour) }).to eq(2)
      expect(page.runners.sum(&:epochs_per_hour)).to eq(page.epochs_per_hour)
    end

    context "with a runner silent for more than five minutes" do
      it "leaves it out" do
        create(:run, :stale, runner_id: "runner-b")

        expect(page.runners).to be_empty
      end
    end

    context "with a slot whose run has already finished" do
      it "leaves it out, so the count and the table agree" do
        create(:run, :claimed, status: "finished", runner_id: "gone-1",
                               finished_at: Time.current)
        create(:run, :claimed, runner_id: "runner-a")

        expect(page.runners.map(&:id)).to eq(["runner-a"])
      end
    end
  end

  describe "#departed_slots" do
    it "counts the slots still heartbeating without a run of their own" do
      create(:run, :claimed, status: "finished", runner_id: "gone-1", finished_at: Time.current)
      create(:run, :claimed, status: "failed", runner_id: "gone-2", finished_at: Time.current)
      create(:run, :claimed, runner_id: "runner-a")

      expect(page.departed_slots).to eq(2)
    end

    context "with every live slot holding a run" do
      it "counts none" do
        create(:run, :claimed, runner_id: "runner-a")

        expect(page.departed_slots).to eq(0)
      end
    end
  end

  describe "#expected_slots" do
    it "reads the parallelism the runner was given" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RUNNER_PARALLELISM").and_return("12")
      create(:run, :claimed, runner_id: "runner-0")

      expect(page.expected_slots).to eq(12)
      expect(page.idle_slots).to eq(11)
    end

    context "with more runners seen than slots expected" do
      it "reports no idle slot rather than a negative one" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RUNNER_PARALLELISM").and_return("1")
        create(:run, :claimed, runner_id: "runner-0")
        create(:run, :claimed, runner_id: "runner-1")

        expect(page.idle_slots).to eq(0)
      end
    end

    context "without the parallelism in the environment" do
      it "knows neither figure" do
        expect(page.expected_slots).to be_nil
        expect(page.idle_slots).to be_nil
      end
    end
  end

  describe "#stalled_runs" do
    it "leaves out a run whose epoch counter moved just now" do
      create(:run, :claimed, epochs_done: 400, epochs_done_at: Time.current)

      expect(page.stalled_runs).to be_empty
    end

    it "flags a live run whose epoch counter has not moved inside the stall window" do
      run = create(:run, :claimed, epochs_done: 400, epochs_done_at: 20.minutes.ago)

      expect(page.stalled_runs.sole).to eq(run)
      expect(page.stalled_runs.sole.last_progress_at).to be_within(1.minute).of(20.minutes.ago)
    end

    context "with a slow run that samples in rare batches but keeps progressing" do
      it "leaves it alone" do
        run = create(:run, :claimed, status: "running", epochs_done: 41_000,
                                     started_at: 3.hours.ago, epochs_done_at: 20.seconds.ago)
        create(:sample, run: run, epoch: 38_000, created_at: 38.minutes.ago)

        expect(page.stalled_runs).to be_empty
      end
    end

    context "with a run that has never reported progress" do
      it "flags it once it has been running long enough" do
        run = create(:run, :claimed, status: "running", started_at: 30.minutes.ago)

        expect(page.stalled_runs.sole).to eq(run)
      end

      it "leaves it alone while it is still starting up" do
        create(:run, :claimed, status: "running", started_at: 1.minute.ago)

        expect(page.stalled_runs).to be_empty
      end
    end

    context "with a run whose runner has gone silent" do
      it "leaves it to the stale-run sweeper" do
        create(:run, :stale, started_at: 30.minutes.ago)

        expect(page.stalled_runs).to be_empty
      end
    end

    it "reads the stalest runs first, in one query" do
      stalest = create(:run, :claimed, status: "running", started_at: 3.hours.ago)
      recent = create(:run, :claimed, epochs_done_at: 20.minutes.ago)

      expect(queries_during { page.stalled_runs }).to eq(1)
      expect(page.stalled_runs).to eq([stalest, recent])
    end

    it "lists no more than a screenful" do
      create_list(:run, Lab::StatusPage::STALLED_LIMIT + 3, :claimed,
                  status: "running", started_at: 3.hours.ago)

      expect(page.stalled_runs.size).to eq(Lab::StatusPage::STALLED_LIMIT)
    end
  end

  describe "#stale_heartbeat_runs" do
    it "flags a claimed run whose runner stopped heartbeating" do
      run = create(:run, :stale, status: "running", heartbeat_at: 30.minutes.ago)

      expect(page.stale_heartbeat_runs.sole).to eq(run)
      expect(page.stale_heartbeat_count).to eq(1)
    end

    context "with a run still inside the heartbeat window" do
      it "leaves it to the runners table" do
        create(:run, :claimed)

        expect(page.stale_heartbeat_runs).to be_empty
      end
    end

    context "with a run that was released" do
      it "leaves it alone" do
        create(:run, status: "pending", heartbeat_at: 30.minutes.ago)

        expect(page.stale_heartbeat_runs).to be_empty
      end
    end
  end

  describe "#worth_a_look" do
    # The run is off the runners table and out of the stall check — both of which only look
    # inside the heartbeat window — while `counts_by_status` still calls it running.
    it "lists a stale-heartbeat run the rest of the page cannot see" do
      run = create(:run, :stale, status: "running", heartbeat_at: 30.minutes.ago)

      expect(page.runners).to be_empty
      expect(page.stalled_runs).to be_empty
      expect(page.live_run_count).to eq(1)
      expect(page.worth_a_look.sole).to have_attributes(run: run, reason: :stale_heartbeat,
                                                        stale_heartbeat?: true)
    end

    it "reads the stalled runs before the stale-heartbeat ones" do
      stalled = create(:run, :claimed, status: "running", started_at: 3.hours.ago)
      silent = create(:run, :stale, status: "running", heartbeat_at: 30.minutes.ago)

      expect(page.worth_a_look.map(&:run)).to eq([stalled, silent])
      expect(page.worth_a_look.map(&:reason)).to eq(%i[no_progress stale_heartbeat])
    end
  end

  describe "#recent_failures" do
    it "lists a run that failed inside the window, newest first" do
      older = create(:run, status: "failed", finished_at: 5.hours.ago, error: "disk full")
      newest = create(:run, status: "failed", finished_at: 1.hour.ago, runner_id: "bench-2",
                            error: "runner panicked")

      expect(page.recent_failures.map(&:id)).to eq([newest.id, older.id])
      expect(page.recent_failures.first).to have_attributes(runner_id: "bench-2",
                                                            error: "runner panicked")
      expect(page.recent_failure_count).to eq(2)
    end

    context "with a failure older than the window" do
      it "leaves it out" do
        create(:run, status: "failed", finished_at: 12.hours.ago, error: "ancient")

        expect(page.recent_failures).to be_empty
        expect(page.recent_failure_count).to be_zero
      end
    end

    context "with a run that finished cleanly" do
      it "leaves it out" do
        create(:run, status: "finished", finished_at: 1.hour.ago)

        expect(page.recent_failures).to be_empty
      end
    end

    context "with failures either side of the six-hour edge" do
      it "keeps the one just inside and drops the one just outside" do
        inside = create(:run, :just_failed, finished_at: 6.hours.ago + 1.minute)
        create(:run, :just_failed, finished_at: 6.hours.ago - 1.minute)

        expect(page.recent_failures.map(&:id)).to eq([inside.id])
        expect(page.recent_failure_count).to eq(1)
      end
    end

    it "lists no more than a screenful and still counts them all" do
      create_list(:run, Lab::StatusPage::FAILURE_LIMIT + 3, :just_failed)

      expect(page.recent_failures.size).to eq(Lab::StatusPage::FAILURE_LIMIT)
      expect(page.recent_failure_count).to eq(Lab::StatusPage::FAILURE_LIMIT + 3)
    end

    it "reads the failures in one query" do
      create(:run, :just_failed)

      expect(queries_during { page.recent_failures }).to eq(1)
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
