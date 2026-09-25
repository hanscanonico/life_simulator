# frozen_string_literal: true

module Experiments
  # The pre-registered reading of the lineage-diversity sweep (`docs/design_record.md`,
  # 2026-09-25, "Lineage diversity after a transition"): each finished run read over its own
  # samples from its emergence on (Lab::LineageDiversityReading::RunReading), each radius
  # counted, and the hypothesis read across the arms. It is interim until every run of the
  # sweep has finished.
  #
  # A run still under way, pending or failed is counted but not read: its last decile is not
  # yet its last. It reads stored samples and changes nothing but the cache. Each finished
  # run's reading is held on its own, and the trend's p on the values it was dealt from, so
  # a view while the sweep runs reads again only the runs that finished since the last one,
  # and deals the 100 000 permutations again only when a value moved.
  class LineageDiversityReadingService
    include Callable

    # A reading is the code's as much as its samples': these are the files that take it, and
    # the Data it is held in (whose Marshal no longer loads once a member is added). Digested
    # once per boot.
    READING_VERSION = Digest::SHA256.hexdigest(
      %w[app/services/experiments/lineage_diversity_reading_service.rb app/models/lab/lineage_diversity_reading.rb
         app/models/lab/lineage_diversity_reading/run_reading.rb app/models/stats/jonckheere_terpstra.rb
         app/presenters/findings/median.rb]
        .map { |path| Rails.root.join(path).binread }.join
    )

    SAMPLE_KEYS = [Lab::LineageDiversityReading::SHARE_KEY, Lab::LineageDiversityReading::DIVERSITY_KEY,
                   *Lab::LineageDiversityReading::DESCRIPTIVE_KEYS].freeze

    RADIUS_SWEEP = "radius"

    # `reading` is nil for a run that has not finished.
    RunRow = Data.define(:run_id, :radius, :seed, :status, :emergence_epoch, :reading) do
      def finished? = status == "finished"

      def cells
        [Lab::LineageDiversityReading::Arm.label_of(radius), seed, run_id, status, reading&.emerged?,
         reading&.verdict, reading&.effective_count, emergence_epoch]
      end
    end

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("lineage_diversity")

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Lab::LineageDiversityReading::Report.new(rows: rows, arms: arms, hypothesis: hypothesis,
                                               final: rows.any? && rows.all?(&:finished?))
    end

    private

    attr_reader :experiment

    def hypothesis
      probe = Lab::LineageDiversityReading::Hypothesis.new(arms: arms, p_value: nil)
      probe.testable? ? probe.with(p_value: trend_p(probe.read_arms.map(&:values))) : probe
    end

    def trend_p(groups)
      Rails.cache.fetch(["experiments/lineage_diversity_reading/trend", READING_VERSION,
                         Digest::SHA256.hexdigest(groups.to_json)]) do
        Stats::JonckheereTerpstra.new(groups)
                                 .p_value(permutations: Lab::LineageDiversityReading::PERMUTATIONS,
                                          random: Random.new(Lab::LineageDiversityReading::PERMUTATION_SEED))
      end
    end

    def arms
      @arms ||= radii.map do |radius|
        emerged, finished = radius_sweep_counts.fetch(radius, [nil, nil])
        Lab::LineageDiversityReading::Arm.new(radius: radius, rows: rows.select { |row| row.radius == radius },
                                              radius_emerged: emerged, radius_finished: finished)
      end
    end

    def radii = Lab::LineageDiversityReading::RADIUS_ORDER & rows.map(&:radius)

    def rows
      @rows ||= runs.map do |run|
        RunRow.new(run_id: run.id, radius: run.params["radius"], seed: run.seed, status: run.status,
                   emergence_epoch: run.emergence_epoch, reading: readings[run.id])
      end
    end

    def runs
      @runs ||= experiment.runs.order(:seed, :id).select(:id, :params, :seed, :status, :emergence_epoch, :updated_at)
                          .to_a.sort_by.with_index { |run, index| [arm_position(run), index] }
    end

    def arm_position(run) = Lab::LineageDiversityReading::RADIUS_ORDER.index(run.params["radius"]).to_i

    # A finished run's samples never change, so its reading is keyed on the run as it stands.
    def readings
      @readings ||= begin
        runs_by_key = runs.select { |run| run.status == "finished" }.index_by { |run| reading_key(run) }
        runs_by_key.empty? ? {} : fetch_readings(runs_by_key)
      end
    end

    def fetch_readings(runs_by_key)
      Rails.cache.fetch_multi(*runs_by_key.keys) { |key| read(runs_by_key.fetch(key)) }
           .transform_keys { |key| runs_by_key.fetch(key).id }
    end

    def reading_key(run)
      ["experiments/lineage_diversity_reading/run", READING_VERSION, run.id, run.emergence_epoch, run.status,
       run.updated_at.iso8601(6)]
    end

    def read(run)
      return Lab::LineageDiversityReading::RunReading::NOT_EMERGED unless run.emerged?

      Lab::LineageDiversityReading::RunReading.read(own_samples(run))
    end

    # One run's samples at a time, and of each only the keys read here: a sweep's samples
    # held at once are what cost the app container its memory on the host-parasite sweep
    # (issue #223).
    def own_samples(run)
      run.samples.where(epoch: run.emergence_epoch..).order(:epoch).pluck(:epoch, observed_values)
    end

    def observed_values
      @observed_values ||= Arel.sql(ActiveRecord::Base.sanitize_sql_array(
        ["jsonb_build_object(#{(['?, samples.values -> ?'] * SAMPLE_KEYS.size).join(', ')})",
         *SAMPLE_KEYS.flat_map { |key| [key, key] }]
      ))
    end

    # The radius sweep's finished founding runs per radius, [emerged, finished].
    def radius_sweep_counts
      @radius_sweep_counts ||= begin
        sweep = Experiment.find_by(slug: RADIUS_SWEEP)
        runs = sweep ? sweep.runs.founding.where(status: "finished").select(:params, :emergence_epoch).to_a : []
        runs.group_by { |run| run.params["radius"] }
            .transform_values { |arm| [arm.count(&:emerged?), arm.size] }
      end
    end
  end
end
