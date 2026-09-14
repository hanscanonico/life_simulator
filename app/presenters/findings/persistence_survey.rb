# frozen_string_literal: true

module Findings
  # Every transitioned run the lab has finished, whichever sweep it belongs to, read
  # through its stored persistence summary: how long the world held the transitioned
  # state, how high its replicator census rose, and whether it climbed back out
  # (DESIGN.md §1.2 — a transition is a state a world can leave).
  #
  # This is a survey of runs that already exist rather than a sweep: the runs come from
  # different grids at different budgets, so it counts outcomes and never estimates a
  # hazard.
  class PersistenceSurvey
    Row = Data.define(:run, :experiment, :persistence, :sample_count_from_transition) do
      delegate :seed, :transition_epoch, to: :run
      delegate :summarised?, :relapsed?, :persisted?, :counted?, :census_peak, :peak_epoch,
               :epochs_persisted, :compact_census_label, to: :persistence

      def relapse_confirmable? = Runs::Persistence.exit_confirmable?(sample_count_from_transition)
    end

    # One set of rows read as persisters against relapsers. The write-up states the same
    # sentence of the whole survey and of each half of the census split, so the shape is
    # named once.
    Outcome = Data.define(:rows) do
      delegate :count, :any?, to: :rows

      def persisted_count = rows.count(&:persisted?)

      def relapsed_count = rows.count(&:relapsed?)

      def relapse_share
        return nil if rows.empty?

        relapsed_count.fdiv(rows.size)
      end
    end

    def self.build = new

    delegate :any?, to: :rows

    def rows
      @rows ||= transitioned_runs.map do |run|
        Row.new(run: run, experiment: run.experiment,
                persistence: run.persistence_summary || Runs::Persistence.none,
                sample_count_from_transition: sample_counts_from_transition.fetch(run.id, 0))
      end
    end

    def transitioned_count = rows.size

    def table_rows = rows.first(ShowPage::MAX_TRANSITIONS)

    def rows_omitted = [rows.size - ShowPage::MAX_TRANSITIONS, 0].max

    def capped? = rows_omitted.positive?

    def summarised_rows = @summarised_rows ||= rows.select(&:summarised?)

    def summarised_count = summarised_rows.size

    def outcome = @outcome ||= Outcome.new(rows: summarised_rows)

    # Persisters whose series was too short from the crossing onwards for a relapse to have
    # been confirmed: they are the part of the persisted count that carries no information.
    def unconfirmable_count
      summarised_rows.count { |row| row.persisted? && !row.relapse_confirmable? }
    end

    def epochs_persisted = @epochs_persisted ||= summarised_rows.map(&:epochs_persisted).compact.sort

    def shortest_persistence = epochs_persisted.first

    def longest_persistence = epochs_persisted.last

    def median_persistence = Median.of(epochs_persisted)

    # The transitioned state is the compression rule's, and the census is a second
    # observable that often disagrees with it, so the outcome is read again on each side of
    # whether the run ever counted a replicating cell at all.
    def counted_outcome = @counted_outcome ||= Outcome.new(rows: summarised_rows.select(&:counted?))

    def uncounted_outcome = @uncounted_outcome ||= Outcome.new(rows: summarised_rows.reject(&:counted?))

    def census_peaks = @census_peaks ||= counted_outcome.rows.map(&:census_peak).sort

    def smallest_census = census_peaks.first

    def largest_census = census_peaks.last

    def median_census = Median.of(census_peaks)

    # The sweeps the survey rests on, named the way their own pages name them.
    def sweeps = @sweeps ||= rows.map(&:experiment).uniq.sort_by(&:name)

    private

    # Ordered the way the table reads: sweep by sweep, and inside a sweep by the epoch the
    # world crossed.
    def transitioned_runs
      @transitioned_runs ||= Run.transitioned.includes(:experiment)
                                .order(:experiment_id, :transition_epoch, :id).to_a
    end

    # One grouped query for the whole page: how many samples each run stored at or after
    # its own crossing, which is what says whether a relapse could have been confirmed.
    def sample_counts_from_transition
      @sample_counts_from_transition ||=
        Sample.joins(:run).where(run_id: transitioned_runs.map(&:id))
              .where("samples.epoch >= runs.transition_epoch").group(:run_id).count
    end
  end
end
