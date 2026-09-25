# frozen_string_literal: true

class AddOrientedSampleIndex < ActiveRecord::Migration[8.1]
  # Only samples taken since the orientation-aware census shipped (#247) carry its share,
  # so the index holds just those rows and a sweep's arm table never scans the samples
  # before them. Its predicate is Runs::OrientedSummariesService::SHARE_PRESENT. `samples`
  # takes thousands of rows a minute, so the build takes no write lock.
  disable_ddl_transaction!

  def change
    add_index :samples, %i[run_id epoch], name: "index_samples_on_run_id_oriented",
                                          where: "(values -> 'replicator_share') IS NOT NULL",
                                          algorithm: :concurrently
  end
end
