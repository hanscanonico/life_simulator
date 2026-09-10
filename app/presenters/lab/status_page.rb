# frozen_string_literal: true

module Lab
  # What the lab is doing right now: the queue, the runners that are alive and how fast
  # epochs are actually being burned.
  class StatusPage
    THROUGHPUT_WINDOW = 1.hour

    Runner = Data.define(:id, :runs, :last_seen, :epochs_done)

    def self.build = new

    def fetched_at = @fetched_at ||= Time.current

    def counts_by_status
      @counts_by_status ||= Run::STATUSES.index_with { |status| status_counts[status].to_i }
    end

    def total_runs = counts_by_status.values.sum

    def runners
      @runners ||= live_runs.group_by(&:runner_id).map do |runner_id, runs|
        Runner.new(id: runner_id, runs: runs.size, last_seen: runs.map(&:heartbeat_at).max,
                   epochs_done: runs.sum(&:epochs_done))
      end.sort_by(&:id)
    end

    # Epochs actually simulated in the last hour: per run, the span between the first and
    # the last sample of the window. Samples are the only record of progress that a
    # crashed or released run cannot rewrite.
    def epochs_per_hour
      @epochs_per_hour ||= Sample.where(created_at: THROUGHPUT_WINDOW.ago..).group(:run_id)
                                 .pluck(Arel.sql("MAX(epoch) - MIN(epoch)")).sum
    end

    def oldest_pending = @oldest_pending ||= Run.pending.order(:created_at, :id).first

    private

    def status_counts = @status_counts ||= Run.group(:status).count

    def live_runs
      @live_runs ||= Run.where(heartbeat_at: Run::STALE_AFTER.ago..).where.not(runner_id: nil)
                        .select(:id, :runner_id, :heartbeat_at, :epochs_done).to_a
    end
  end
end
