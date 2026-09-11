# frozen_string_literal: true

module Programme
  # Where the research programme stands, in five numbers read live from the lab database:
  # what has been queued, what has finished, and the largest replicator census any run has
  # ever recorded. Every page that carries the status strip builds one of these.
  class Status
    def self.build = new

    def sweeps_queued = @sweeps_queued ||= Experiment.count

    def runs_finished = @runs_finished ||= Run.where(status: "finished").count

    def epochs_simulated = @epochs_simulated ||= Run.sum(:epochs_done)

    def seeds_transitioned
      @seeds_transitioned ||= Run.where(status: "finished").where.not(transition_epoch: nil).count
    end

    # nil until some sample has counted a replicator. The predicate matches
    # `index_samples_on_run_id_replicated` (db/schema.rb) exactly, so the maximum is read
    # off that partial index instead of scanning every sample ever taken.
    def peak_replicator_count
      return @peak_replicator_count if defined?(@peak_replicator_count)

      @peak_replicator_count = Sample.where("values -> 'replicator_count' > '0'::jsonb")
                                     .maximum(Arel.sql("(values ->> 'replicator_count')::numeric"))
    end
  end
end
