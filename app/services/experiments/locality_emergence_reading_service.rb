# frozen_string_literal: true

module Experiments
  # The locality-emergence sweep read as pre-registered (`docs/design_record.md`, 2026-09-27):
  # each finished run emerged or not, each radius counted, and H-peak and H-shape read across
  # the arms. It is interim until every run of the sweep has finished; a run still under way,
  # pending or failed is listed but not counted.
  class LocalityEmergenceReadingService
    include Callable

    # `emerged` is nil for a run that has not finished.
    RunRow = Data.define(:run_id, :radius, :seed, :status, :emergence_epoch, :emerged) do
      def finished? = status == "finished"

      def cells
        [Lab::LocalityEmergenceReading::Arm.label_of(radius), seed, run_id, status, emerged, emergence_epoch]
      end
    end

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("locality_emergence")

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Lab::LocalityEmergenceReading::Report.new(rows: rows, arms: arms,
                                                peak: Lab::LocalityEmergenceReading::Peak.new(arms: arms),
                                                shape: Lab::LocalityEmergenceReading::Shape.read(arms),
                                                final: rows.any? && rows.all?(&:finished?))
    end

    private

    attr_reader :experiment

    def arms
      @arms ||= (Lab::LocalityEmergenceReading::RADIUS_ORDER & rows.map(&:radius)).map do |radius|
        Lab::LocalityEmergenceReading::Arm.new(radius: radius, rows: rows.select { |row| row.radius == radius })
      end
    end

    def rows
      @rows ||= runs.map do |run|
        finished = run.status == "finished"
        RunRow.new(run_id: run.id, radius: run.params["radius"], seed: run.seed, status: run.status,
                   emergence_epoch: run.emergence_epoch, emerged: finished ? emerged_ids.include?(run.id) : nil)
      end
    end

    def runs
      @runs ||= experiment.runs.order(:seed, :id).select(:id, :params, :seed, :status, :emergence_epoch).to_a
                          .sort_by.with_index { |run, index| [arm_position(run), index] }
    end

    def arm_position(run) = Lab::LocalityEmergenceReading::RADIUS_ORDER.index(run.params["radius"]).to_i

    # The finished runs with a confirmed crossing and a sample at or after it that reads
    # `replicator_share` as a number of at least MIN_SHARE: a sample without the share, or
    # with something other than a number in it, is no reading.
    def emerged_ids
      @emerged_ids ||= Sample.joins(:run).merge(experiment.runs.where(status: "finished"))
                             .where("samples.epoch >= runs.emergence_epoch")
                             .where("jsonb_typeof(samples.values -> :key) = 'number' " \
                                    "AND (samples.values ->> :key)::float >= :share",
                                    key: Lab::LocalityEmergenceReading::SHARE_KEY,
                                    share: Lab::LocalityEmergenceReading::MIN_SHARE)
                             .distinct.pluck(:run_id).to_set
    end
  end
end
