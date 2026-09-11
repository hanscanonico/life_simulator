# frozen_string_literal: true

class AddReplicatedSampleIndex < ActiveRecord::Migration[8.1]
  # The census names the runs a replicator was ever counted in, and a sample of a run that
  # never replicated is of no interest to it, so the index carries only the rows that pass
  # the comparison — an index-only scan over a few thousand rows instead of a sequential
  # scan over every sample ever stored. `samples` takes thousands of rows a minute, so the
  # build takes no write lock.
  disable_ddl_transaction!

  def change
    add_index :samples, :run_id, name: "index_samples_on_run_id_replicated",
                                 where: "(values -> 'replicator_count') > '0'::jsonb",
                                 algorithm: :concurrently
  end
end
