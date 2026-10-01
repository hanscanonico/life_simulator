# frozen_string_literal: true

module Experiments
  # The reach-cap128 sweep read as pre-registered (`docs/design_record.md`, 2026-10-01):
  # its runs at radius 4 against the founding runs of sweep 9's economy-off cap-128 control,
  # each emerged or not on the orientation-aware census of the worlds it kept, and
  # H-reach128 read across the two. It is interim until every run of both arms has finished
  # and the readings pass has read every world each kept; a run short of either is listed
  # but not counted.
  class ReachCap128ReadingService
    include Callable

    # `emerged` is nil for a run that is not counted yet.
    RunRow = Data.define(:run_id, :arm, :seed, :status, :emergence_epoch, :measured, :emerged, :terminal_share,
                         :dominant_raw_len, :dominant_instruction_count, :dominant_self_replicates) do
      def finished? = status == "finished"

      def counted? = !emerged.nil?

      def eligible_parent?
        emerged == true && terminal_share.is_a?(Numeric) && terminal_share >= Lab::ReachCap128Reading::PARENT_SHARE
      end

      def cells
        [arm, seed, run_id, status, emergence_epoch, measured, emerged, terminal_share, dominant_raw_len,
         dominant_instruction_count, dominant_self_replicates]
      end
    end

    # Lab::ReachCap128Reading::SELF_REPLICATES_KEY, read as jsonb so a stored boolean stays one.
    SELF_REPLICATES = "snapshot_readings.values -> 'dominant_self_replicates'"
    TREATMENT_LABEL = "radius #{Lab::ReachCap128Reading::TREATMENT_RADIUS}".freeze
    CONTROL_LABEL = "control, radius 1"

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("reach_cap128")

    # A run emerged where it crossed and some world it still keeps, read from the crossing
    # on, holds the share: true or false, and nil for a run not every kept world of which has
    # been read. A reading of a world pruned since is left out: a pass that read a run before
    # the prune job thinned it would give it ten worlds for every one the control was read on.
    def self.emergence(emergence_epoch:, summary:, kept:)
      return nil unless summary.measured?
      return false if emergence_epoch.nil?

      summary.readings.any? do |reading|
        kept.include?(reading.epoch) && reading.epoch >= emergence_epoch &&
          reading.share >= Lab::ReachCap128Reading::MIN_SHARE
      end
    end

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      arms = [arm(TREATMENT_LABEL, treatment_runs), arm(CONTROL_LABEL, control_runs)]
      rows = arms.flat_map(&:rows)

      comparison = Lab::ReachCap128Reading::Comparison.new(treatment: arms.first, control: arms.last)

      Lab::ReachCap128Reading::Report.new(
        rows: rows, arms: arms, comparison: comparison,
        final: treatment_runs.any? && control_runs.any? && rows.all? { |row| row.finished? && row.measured }
      )
    end

    private

    attr_reader :experiment

    def arm(label, runs)
      Lab::ReachCap128Reading::Arm.new(label: label, rows: runs.map { |run| row(label, run) })
    end

    def row(label, run)
      summary = summaries.fetch(run.id)
      finished = run.status == "finished"
      emerged = finished ? emergence(run) : nil
      sample = emerged ? last_samples.fetch(run.id, {}) : {}

      RunRow.new(run_id: run.id, arm: label, seed: run.seed, status: run.status,
                 emergence_epoch: run.emergence_epoch, measured: summary.measured?, emerged: emerged,
                 terminal_share: summary.terminal_share,
                 dominant_raw_len: sample[Lab::ReachCap128Reading::RAW_LEN_KEY],
                 dominant_instruction_count: sample[Lab::ReachCap128Reading::INSTRUCTION_KEY],
                 dominant_self_replicates: emerged ? terminal_self_replicates[run.id] : nil)
    end

    def treatment_runs = @treatment_runs ||= runs_of(experiment.runs.founding)

    # Matched as a rake argument is, canonically, so 0 and 0.0 are one value.
    def control_runs
      @control_runs ||= begin
        control = Experiment.find_by(slug: Lab::ReachCap128Reading::CONTROL_EXPERIMENT)
        runs = control.nil? ? [] : runs_of(control.runs.founding)
        runs.select do |run|
          Lab::ReachCap128Reading::CONTROL_ARM.all? do |name, value|
            Lab::CanonicalParams.same_value?(Lab::CanonicalParams.resolve(run.params)[name], value)
          end
        end
      end
    end

    def runs_of(scope)
      scope.order(:seed, :id).select(:id, :params, :seed, :status, :epochs, :emergence_epoch).to_a
    end

    def summaries = @summaries ||= Runs::OrientedSummariesService.call(runs: treatment_runs + control_runs)

    def emergence(run)
      self.class.emergence(emergence_epoch: run.emergence_epoch, summary: summaries.fetch(run.id),
                           kept: kept_epochs.fetch(run.id, Set.new))
    end

    def kept_epochs
      @kept_epochs ||= Snapshot.where(run_id: (treatment_runs + control_runs).map(&:id)).pluck(:run_id, :epoch)
                               .group_by(&:first).transform_values { |pairs| pairs.to_set(&:last) }
    end

    def emerged_ids
      @emerged_ids ||= (treatment_runs + control_runs).select { |run| run.status == "finished" && emergence(run) }
                                                      .map(&:id)
    end

    # The values of each emerged run's last live sample.
    def last_samples
      @last_samples ||= Sample.where(run_id: emerged_ids).select("DISTINCT ON (run_id) run_id, values")
                              .order(:run_id, epoch: :desc).to_h { |sample| [sample.run_id, sample.values] }
    end

    # Whether the dominant tape of each emerged run's terminal stored world self-replicates.
    def terminal_self_replicates
      @terminal_self_replicates ||= SnapshotReading.joins(:run)
                                                   .where(run_id: emerged_ids, instrument: Lab::ReachCap128Reading::INSTRUMENT)
                                                   .where("snapshot_readings.epoch = snapshot_readings.source_epoch")
                                                   .where("snapshot_readings.epoch = runs.epochs")
                                                   .pluck(:run_id, Arel.sql(SELF_REPLICATES)).to_h
    end
  end
end
