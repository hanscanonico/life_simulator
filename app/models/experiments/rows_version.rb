# frozen_string_literal: true

module Experiments
  # A fingerprint of some runs and of the rows they hold in tables written without touching
  # the run — a corpus pass's readings and rescores, the worlds a runner stores and a prune
  # drops — for a cache key over readings of them: per table, how many rows there are and
  # when the latest was written, in one statement. A row added, deleted, or upserted with
  # new values (which moves its `updated_at`) moves it.
  module RowsVersion
    def self.of(runs, *models)
      parts = [version_of(runs, Run), *models.map { |model| version_of(model.where(run_id: runs.select(:id)), model) }]
      union = parts.map(&:arel).reduce { |left, right| Arel::Nodes::UnionAll.new(left, right) }

      ActiveRecord::Base.connection.select_rows(Arel::SelectManager.new.project(Arel.star).from(union.as("versions")))
                        .sort
    end

    # The latest write as text, so the key keeps the microseconds a Time loses as one.
    def self.version_of(scope, model)
      table = model.arel_table
      scope.select(Arel::Nodes.build_quoted(model.table_name), Arel.star.count,
                   Arel::Nodes::NamedFunction.new("CAST", [table[:updated_at].maximum.as("text")]))
    end
  end
end
