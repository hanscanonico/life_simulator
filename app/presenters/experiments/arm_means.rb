# frozen_string_literal: true

module Experiments
  # The mean of each series of ArmSeries at every sampled epoch, for every arm of every swept
  # axis of a sweep, read in one pass over the sweep's samples: a Hash from an axis's name,
  # the arm's index among the axis's values and the metric to the arm's `[epoch, mean]`
  # points, plain data a cache can hold.
  #
  # A pass over a sweep's samples is the whole cost of the page: the host-parasite sweep is
  # 1 260 runs of 2 000 samples, and one query per arm and series read those 2.5 M rows 54
  # times over, past the proxy's timeout (issue #236). Here the samples are read once,
  # summed per combination of arms a run belongs to — fourteen for that sweep — and the
  # combinations are folded into each axis's arms over those few sums. The fold divides the
  # arm's exact numeric sum by its count, which is what AVG computes, so every mean is the
  # one the per-arm query returned.
  class ArmMeans
    def self.read(axes:, runs:, series:) = new(axes: axes, runs: runs, series: series).read

    def initialize(axes:, runs:, series:)
      @axes = axes
      @runs = runs
      @series = series
    end

    def read
      return {} if arms_by_combination.empty?

      Sample.connection.select_all(means_sql).cast_values.each_with_object({}) do |(axis, arm, epoch, *averages), means|
        series.zip(averages).each do |one, average|
          (means[[axes[axis].name, arm, one.metric]] ||= []) << [epoch, average] unless average.nil?
        end
      end
    end

    private

    attr_reader :axes, :runs, :series

    # A run sits in one arm of every axis it matches a value of: its combination is the
    # tuple of those arms, so two runs of a combination fall in the same arm on every axis.
    def combination_of(run)
      axes.map { |axis| axis.values.each_index.select { |arm| axis.matches?(run.params, axis.values[arm]) } }
    end

    def combinations = @combinations ||= runs.map { |run| combination_of(run) }.uniq

    def arms_by_combination
      @arms_by_combination ||= combinations.each_with_index.flat_map do |combination, index|
        combination.each_with_index.flat_map { |arms, axis| arms.map { |arm| [index, axis, arm] } }
      end
    end

    def means_sql
      combination_ids = runs.map { |run| combinations.index(combination_of(run)) }

      ActiveRecord::Base.sanitize_sql_array(
        [<<~SQL.squish, runs.map(&:id), combination_ids, *arms_by_combination.transpose]
          WITH runs_by_combination(run_id, combination) AS (
            SELECT * FROM unnest(ARRAY[?]::bigint[], ARRAY[?]::integer[])
          ), arms_by_combination(combination, axis, arm) AS (
            SELECT * FROM unnest(ARRAY[?]::integer[], ARRAY[?]::integer[], ARRAY[?]::integer[])
          ), partials AS (
            SELECT runs_by_combination.combination, samples.epoch, #{partial_columns}
            FROM samples
            JOIN runs_by_combination ON runs_by_combination.run_id = samples.run_id
            CROSS JOIN LATERAL jsonb_to_record(samples.values) AS readings(#{reading_columns})
            GROUP BY runs_by_combination.combination, samples.epoch
          )
          SELECT arms_by_combination.axis, arms_by_combination.arm, partials.epoch, #{mean_columns}
          FROM partials JOIN arms_by_combination ON arms_by_combination.combination = partials.combination
          GROUP BY arms_by_combination.axis, arms_by_combination.arm, partials.epoch
          ORDER BY arms_by_combination.axis, arms_by_combination.arm, partials.epoch
        SQL
      )
    end

    # Each series pulled out of a sample's values once, as a jsonb column of its own, so
    # what gets sorted into the groups is these few readings rather than every key the
    # engine wrote: sorting whole samples spilled 2 GiB to disk on the host-parasite sweep
    # and was most of the query. A reading is still the value the per-arm query read —
    # the jsonb number cast straight to numeric.
    def reading_columns = series.map { |one| "#{quoted(one)} jsonb" }.join(", ")

    # The type test keeps a reading the engine reported as null — nothing replicated — out
    # of both the sum and the count, and makes the cast behind it safe.
    def partial_columns
      series.each_with_index.map do |one, index|
        reading = "readings.#{quoted(one)}"

        "SUM(CASE WHEN jsonb_typeof(#{reading}) = 'number' THEN #{reading}::numeric END) AS sum_#{index}, " \
          "COUNT(CASE WHEN jsonb_typeof(#{reading}) = 'number' THEN 1 END) AS count_#{index}"
      end.join(", ")
    end

    # A combination-and-epoch with no reading of a series counts zero, and an arm whose
    # every combination does has no mean there: NULLIF leaves that epoch out of the line,
    # as the per-arm query, which never grouped it, did.
    def mean_columns
      series.each_index.map { |index| "SUM(partials.sum_#{index}) / NULLIF(SUM(partials.count_#{index}), 0)" }
            .join(", ")
    end

    def quoted(one) = Sample.connection.quote_column_name(one.metric)
  end
end
