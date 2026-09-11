# frozen_string_literal: true

module Lab
  # What the lab is doing right now: the queue, the runners that are alive and how fast
  # epochs are actually being burned.
  class StatusPage
    THROUGHPUT_WINDOW = 1.hour
    # A live run whose epoch counter has not moved for this long is worth a look. The
    # runner heartbeats every 30 s with the epoch it is on, so this is thirty missed
    # advances and not a slow cadence.
    STALL_AFTER = 15.minutes
    STALLED_LIMIT = 20
    LAST_PROGRESS = "COALESCE(runs.epochs_done_at, runs.started_at, runs.claimed_at)"

    Runner = Data.define(:id, :run_ids, :last_seen, :epochs_done, :epochs_per_hour)

    def self.build = new

    def fetched_at = @fetched_at ||= Time.current

    def counts_by_status
      @counts_by_status ||= Run::STATUSES.index_with { |status| status_counts[status].to_i }
    end

    def total_runs = counts_by_status.values.sum

    def runners
      @runners ||= live_runs.group_by(&:runner_id)
                            .map { |runner_id, runs| slot(runner_id, runs) }.sort_by(&:id)
    end

    def expected_slots = @expected_slots ||= ENV["RUNNER_PARALLELISM"].presence&.to_i

    def idle_slots = expected_slots && [expected_slots - runners.size, 0].max

    # Slots that heartbeated inside the window but hold no claimed or running run: what a
    # destroyed runner container leaves behind for up to `Run::STALE_AFTER`. Counted apart
    # from `runners` so the header and the table always describe the same set.
    def departed_slots = (recent_runner_ids - runners.map(&:id)).size

    # Epochs actually simulated in the last hour: per run, the span between the first and
    # the last sample of the window. Samples are the only record of progress that a
    # crashed or released run cannot rewrite.
    def epochs_per_hour = hourly_epochs_by_run.values.sum

    # Runs that still heartbeat — so the runner process is alive — yet whose `epochs_done`
    # has not advanced in `STALL_AFTER`: the shape a wedged simulation takes. The rule keys
    # on progress and not on samples, because samples say nothing about a slow run: the
    # runner flushes them in batches of 50 (`http_sink::BATCH_SIZE`), so a healthy 512x256
    # control run at `sample_every` 50 posts a batch roughly every 25 minutes. `epochs_done`
    # rides every heartbeat instead, and `epochs_done_at` records when it last moved.
    def stalled_runs
      @stalled_runs ||= Run.where(status: %w[claimed running], heartbeat_at: Run::STALE_AFTER.ago..)
                           .where("#{LAST_PROGRESS} < ?", STALL_AFTER.ago)
                           .select("runs.*", "#{LAST_PROGRESS} AS last_progress_at")
                           .order(Arel.sql("#{LAST_PROGRESS} ASC"))
                           .limit(STALLED_LIMIT).to_a
    end

    def oldest_pending = @oldest_pending ||= Run.pending.order(:created_at, :id).first

    private

    def slot(runner_id, runs)
      run_ids = runs.map(&:id)
      Runner.new(id: runner_id, run_ids: run_ids, last_seen: runs.map(&:heartbeat_at).max,
                 epochs_done: runs.sum(&:epochs_done),
                 epochs_per_hour: run_ids.sum { |id| hourly_epochs_by_run[id].to_i })
    end

    def status_counts = @status_counts ||= Run.group(:status).count

    def live_runs
      @live_runs ||= Run.where(status: %w[claimed running], heartbeat_at: Run::STALE_AFTER.ago..)
                        .where.not(runner_id: nil)
                        .select(:id, :runner_id, :heartbeat_at, :epochs_done).to_a
    end

    def recent_runner_ids
      @recent_runner_ids ||= Run.where(heartbeat_at: Run::STALE_AFTER.ago..)
                                .where.not(runner_id: nil).distinct.pluck(:runner_id)
    end

    def hourly_epochs_by_run
      @hourly_epochs_by_run ||= Sample.where(created_at: THROUGHPUT_WINDOW.ago..).group(:run_id)
                                      .pluck(:run_id, Arel.sql("MAX(epoch) - MIN(epoch)")).to_h
    end
  end
end
