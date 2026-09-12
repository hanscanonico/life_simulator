# frozen_string_literal: true

module Findings
  # Every transitioned run the lab has finished, whichever sweep it belongs to, read
  # through its stored persistence summary: how long the world held the transitioned
  # state, how high its replicator census rose, and whether it climbed back out
  # (DESIGN.md §1.2 — a transition is a state a world can leave).
  #
  # This is a survey of runs that already exist rather than a sweep: the runs come from
  # different grids at different budgets, so it counts outcomes and never estimates a
  # hazard. It reads and changes nothing.
  class PersistenceSurvey
    MAX_ROWS = 100

    # A run needs `hold_samples + 1` samples after its crossing for an exit to be
    # confirmed in (docs/design_record.md, 2026-09-12); one with fewer reads as persisted
    # because nothing could have flagged it otherwise.
    CONFIRMABLE_SAMPLES = Runs::PersistenceSummaryService::EXIT_SAMPLES

    Row = Data.define(:run, :experiment, :persistence, :samples_after_transition) do
      def summarised? = persistence.present?

      def relapsed? = summarised? && persistence.relapsed?

      def persisted? = summarised? && !persistence.relapsed?

      def epochs_persisted = persistence&.epochs_persisted

      def census_peak = persistence&.census_peak

      def peak_epoch = persistence&.peak_epoch

      def counted? = summarised? && persistence.counted?

      def relapse_confirmable? = samples_after_transition >= CONFIRMABLE_SAMPLES
    end

    def self.build = new

    delegate :any?, to: :rows

    def rows
      @rows ||= transitioned_runs.map do |run|
        Row.new(run: run, experiment: run.experiment, persistence: run.persistence_summary,
                samples_after_transition: samples_after_transition.fetch(run.id, 0))
      end
    end

    def table_rows = rows.first(MAX_ROWS)

    def capped? = rows.size > MAX_ROWS

    def transitioned_count = rows.size

    def summarised_rows = @summarised_rows ||= rows.select(&:summarised?)

    def summarised_count = summarised_rows.size

    def persisted_rows = @persisted_rows ||= summarised_rows.select(&:persisted?)

    def persisted_count = persisted_rows.size

    def relapsed_rows = @relapsed_rows ||= summarised_rows.select(&:relapsed?)

    def relapsed_count = relapsed_rows.size

    # Persisters whose run was too short after the crossing for a relapse to have been
    # confirmed: they are the part of the persisted count that carries no information.
    def unconfirmable_count = persisted_rows.count { |row| !row.relapse_confirmable? }

    def relapse_share
      return nil if summarised_count.zero?

      relapsed_count.fdiv(summarised_count)
    end

    def epochs_persisted = @epochs_persisted ||= summarised_rows.map(&:epochs_persisted).compact.sort

    def shortest_persistence = epochs_persisted.first

    def longest_persistence = epochs_persisted.last

    def median_persistence = median(epochs_persisted)

    def counted_rows = @counted_rows ||= summarised_rows.select(&:counted?)

    def counted_count = counted_rows.size

    def census_peaks = @census_peaks ||= counted_rows.map(&:census_peak).sort

    def largest_census = census_peaks.last

    def median_census = median(census_peaks)

    def largest_census_row = counted_rows.max_by(&:census_peak)

    # The transitioned state is the compression rule's, and the census is a second
    # observable that often disagrees with it, so both halves of the outcome are split by
    # whether the run ever counted a replicating cell at all.
    def counted_persisted_count = counted_rows.count(&:persisted?)

    def counted_relapsed_count = counted_rows.count(&:relapsed?)

    def uncounted_rows = @uncounted_rows ||= summarised_rows.reject(&:counted?)

    def uncounted_count = uncounted_rows.size

    def uncounted_persisted_count = uncounted_rows.count(&:persisted?)

    def uncounted_relapsed_count = uncounted_rows.count(&:relapsed?)

    # The sweeps the survey rests on, named the way their own pages name them.
    def sweeps = @sweeps ||= rows.map(&:experiment).uniq.sort_by(&:name)

    private

    # Ordered the way the table reads: sweep by sweep, and inside a sweep by the epoch the
    # world crossed.
    def transitioned_runs
      @transitioned_runs ||= Run.terminal.where.not(transition_epoch: nil)
                                .includes(:experiment).order(:experiment_id, :transition_epoch, :id).to_a
    end

    # One grouped query for the whole page: how many samples each run stored at or after
    # its own crossing, which is what says whether a relapse could have been confirmed.
    def samples_after_transition
      @samples_after_transition ||=
        Sample.joins(:run).where(run_id: transitioned_runs.map(&:id))
              .where("samples.epoch >= runs.transition_epoch").group(:run_id).count
    end

    # The lower of the two middle values on an even count: the distribution is small
    # enough that an interpolated median would suggest a resolution it does not have.
    def median(values)
      return nil if values.empty?

      values[(values.size - 1) / 2]
    end
  end
end
