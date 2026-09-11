# frozen_string_literal: true

module Api
  # The read side `runner rescore-corpus` works from: which finished runs of an experiment
  # hold which stored worlds, so the runner can re-measure a whole corpus without walking
  # the runs one request at a time.
  class ExperimentsController < BaseController
    def corpus
      experiment = Experiment.find_by!(slug: params.fetch(:slug))
      runs = experiment.runs.terminal.order(:id).to_a
      epochs = restorable_epochs(runs)
      render json: { slug: experiment.slug,
                     runs: runs.map { |run| described(run, epochs.fetch(run.id, [])) } }
    end

    private

    def described(run, epochs)
      { id: run.id, seed: run.seed, params: run.params, status: run.status,
        transition_epoch: run.transition_epoch, epochs: epochs }
    end

    def restorable_epochs(runs)
      Snapshot.restorable.where(run: runs).order(:run_id, :epoch).pluck(:run_id, :epoch)
              .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
    end
  end
end
