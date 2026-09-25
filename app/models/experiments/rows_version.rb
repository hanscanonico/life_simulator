# frozen_string_literal: true

module Experiments
  # A fingerprint of some runs and of the rows they hold in tables written without touching
  # the run — a corpus pass's readings and rescores, the worlds a runner stores and a prune
  # drops — for a cache key over readings of them: per table, how many rows there are and a
  # sum of a hash of each row's id and `updated_at`, in one statement. A row added, deleted,
  # or upserted with new values (which moves its `updated_at`) moves it.
  module RowsVersion
    def self.of(runs, *models)
      parts = [version_of(runs, Run), *models.map { |model| version_of(model.where(run_id: runs.select(:id)), model) }]
      union = parts.map(&:arel).reduce { |left, right| Arel::Nodes::UnionAll.new(left, right) }

      ActiveRecord::Base.connection.select_rows(Arel::SelectManager.new.project(Arel.star).from(union.as("versions")))
                        .sort
    end

    # Every row's own timestamp rather than the latest one: a write's timestamp is taken
    # before it commits, so of two concurrent writers the one that commits last can land
    # under a timestamp older than the latest already read, and a `max(updated_at)` would
    # not move.
    def self.version_of(scope, model)
      table = model.quoted_table_name
      row = "hashtextextended(#{table}.id::text || '@' || #{table}.updated_at::text, 0)"
      scope.select(Arel::Nodes.build_quoted(model.table_name), Arel.star.count, Arel.sql("SUM(#{row})::text"))
    end
  end
end
