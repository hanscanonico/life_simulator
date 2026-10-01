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
    # The held sums are this file's as much as the samples'. Digested once per boot.
    VERSION = Digest::SHA256.hexdigest(Rails.root.join("app/presenters/experiments/arm_means.rb").binread)

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
      arms = ActiveRecord::Base.sanitize_sql_array(
        ["SELECT * FROM unnest(ARRAY[?]::integer[], ARRAY[?]::integer[], ARRAY[?]::integer[])",
         *arms_by_combination.transpose]
      )

      <<~SQL.squish
        WITH arms_by_combination(combination, axis, arm) AS (#{arms}),
        partials AS (#{partials_sql})
        SELECT arms_by_combination.axis, arms_by_combination.arm, partials.epoch, #{mean_columns}
        FROM partials JOIN arms_by_combination ON arms_by_combination.combination = partials.combination
        GROUP BY arms_by_combination.axis, arms_by_combination.arm, partials.epoch
        ORDER BY arms_by_combination.axis, arms_by_combination.arm, partials.epoch
      SQL
    end

    # A terminal run's samples never change. A sweep holding runs of both kinds sums its
    # terminal runs' samples once, holds those sums, and adds each view's sums of the runs
    # still under way to them: re-reading every sample cost the from-emerged page more
    # than a second on every view while any of its children ran. A sweep of one kind has
    # nothing to split, and its reading is held whole by the page.
    def partials_sql
      terminal, live = runs.partition(&:terminal?)
      return partials_of(runs) if terminal.empty? || live.empty?

      held = held_partials_sql(terminal)
      held ? "#{partials_of(live)} UNION ALL #{held}" : partials_of(live)
    end

    # The sums of each series per combination and epoch over some runs' samples.
    def partials_of(some_runs, as_text: false)
      ids = some_runs.map(&:id)

      ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, ids, ids.map { |id| combination_ids.fetch(id) }])
        SELECT runs_by_combination.combination, samples.epoch, #{partial_columns(as_text:)}
        FROM samples
        JOIN (SELECT * FROM unnest(ARRAY[?]::bigint[], ARRAY[?]::integer[])) AS runs_by_combination(run_id, combination)
          ON runs_by_combination.run_id = samples.run_id
        CROSS JOIN LATERAL jsonb_to_record(samples.values) AS readings(#{reading_columns})
        GROUP BY runs_by_combination.combination, samples.epoch
      SQL
    end

    # The held sums go back to Postgres as they came out of it, text, so each keeps its
    # scale: the scale of a numeric is part of what dividing it returns, and a sum's is the
    # widest of its terms', so the mean is the digit-for-digit one of a single pass.
    def held_partials_sql(terminal)
      rows = held_partials(terminal)
      return nil if rows.empty?

      types = ["integer", "integer", *series.flat_map { %w[numeric bigint] }]
      arrays = rows.transpose.zip(types).map { |values, type| "#{array_literal(values)}::#{type}[]" }
      "SELECT * FROM unnest(#{arrays.join(', ')})"
    end

    # One literal per column: an ARRAY[...] constructor is an expression per element for
    # the parser, and a live sweep's held sums are tens of thousands of them. Every element
    # is an integer or a numeric Postgres wrote itself.
    def array_literal(values)
      Sample.connection.quote("{#{values.map { |value| value.nil? ? 'NULL' : value }.join(',')}}")
    end

    # Held by the combination itself rather than its index, which the runs still under way
    # can move.
    def held_partials(terminal)
      versions = terminal.map { |run| [run.id, run.status, run.updated_at.iso8601(6), combination_of(run)] }
      key = Digest::SHA256.hexdigest([series.map(&:metric), versions].to_json)
      rows = Rails.cache.fetch(["experiments/arm_means/terminal", VERSION, key]) do
        Sample.connection.select_rows(partials_of(terminal, as_text: true))
              .map { |combination, *sums| [combinations.fetch(combination), *sums] }
      end
      rows.map { |combination, *sums| [combinations.index(combination), *sums] }
    end

    def combination_ids
      @combination_ids ||= runs.to_h { |run| [run.id, combinations.index(combination_of(run))] }
    end

    # Each series pulled out of a sample's values once, as a jsonb column of its own, so
    # what gets sorted into the groups is these few readings rather than every key the
    # engine wrote: sorting whole samples spilled 2 GiB to disk on the host-parasite sweep
    # and was most of the query. A reading is still the value the per-arm query read —
    # the jsonb number cast straight to numeric.
    def reading_columns = series.map { |one| "#{quoted(one)} jsonb" }.join(", ")

    # The type test keeps a reading the engine reported as null — nothing replicated — out
    # of both the sum and the count, and makes the cast behind it safe.
    def partial_columns(as_text: false)
      series.each_with_index.map do |one, index|
        reading = "readings.#{quoted(one)}"

        "SUM(CASE WHEN jsonb_typeof(#{reading}) = 'number' THEN #{reading}::numeric END)#{'::text' if as_text} " \
          "AS sum_#{index}, " \
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
