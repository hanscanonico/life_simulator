# frozen_string_literal: true

module Experiments
  # The replicator census of a sweep's stored worlds read at every `top_k` a corpus pass
  # measured. `top_k` is locked at 16 for a run's own metrics (DESIGN.md §1.2), so the
  # question a proposal to move it has to answer is how many runs the census calls dead at
  # 16 and alive at a wider window: that is `newly_positive_runs`, counted against the
  # same runs at the baseline.
  #
  # Two grouped aggregates whatever the sweep holds — one over the readings, one over
  # (top_k, run) — so the page never queries per run.
  class RescoreSummary
    BASELINE_TOP_K = 16

    MEDIAN = "percentile_cont(0.5) within group (order by replicator_count::double precision)"

    Row = Data.define(:top_k, :worlds, :runs_measured, :runs_with_replicators,
                      :median_replicator_count, :max_replicator_count, :newly_positive_runs)

    def self.build(experiment:) = new(experiment: experiment)

    def initialize(experiment:)
      @experiment = experiment
    end

    delegate :any?, to: :rows

    def rows = @rows ||= aggregates.map { |top_k, aggregate| row(top_k, aggregate) }

    def baseline_top_k = BASELINE_TOP_K

    private

    def row(top_k, aggregate)
      worlds, median, max = aggregate
      peaks = peaks_by_top_k.fetch(top_k, {})

      Row.new(top_k: top_k, worlds: worlds, runs_measured: peaks.size,
              runs_with_replicators: peaks.count { |_, peak| peak.to_i.positive? },
              median_replicator_count: median, max_replicator_count: max,
              newly_positive_runs: newly_positive(top_k, peaks))
    end

    # A run with no reading at the baseline is no evidence either way: only a run the
    # corpus pass measured at both windows can be said to have changed verdict. A pass
    # that skipped the baseline window altogether counts nothing rather than reporting a
    # zero that would read as "no run changed verdict".
    def newly_positive(top_k, peaks)
      return nil if top_k == BASELINE_TOP_K || baseline_peaks.empty?

      peaks.count do |run_id, peak|
        baseline = baseline_peaks[run_id]
        baseline.present? && !baseline.positive? && peak.to_i.positive?
      end
    end

    def baseline_peaks = @baseline_peaks ||= peaks_by_top_k.fetch(BASELINE_TOP_K, {})

    # The peak reading of each run at each window: a run counts as holding a replicator if
    # any of its stored worlds did, which is the census the runs table already reports.
    def peaks_by_top_k
      @peaks_by_top_k ||= rescores.group(:top_k, :run_id).maximum(:replicator_count)
                                  .group_by { |(top_k, _), _| top_k }
                                  .transform_values { |pairs| pairs.to_h { |(_, run_id), peak| [run_id, peak] } }
    end

    def aggregates
      @aggregates ||= rescores.group(:top_k).order(:top_k)
                              .pluck(Arel.sql("top_k"), Arel.sql("count(*)"),
                                     Arel.sql(MEDIAN), Arel.sql("max(replicator_count)"))
                              .to_h { |top_k, *aggregate| [top_k, aggregate] }
    end

    def rescores = Rescore.where(run_id: @experiment.runs.select(:id))
  end
end
