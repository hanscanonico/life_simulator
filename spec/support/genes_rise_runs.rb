# frozen_string_literal: true

# The genes-rise sweep, its parents in the reach-cap128 sweep and its children's own samples,
# for the specs of its builder and its reading.
module GenesRiseRuns
  # The sweep as defined, but for the count of qualifying parents its rule sets aside, `skip`
  # rather than out-compute's fifty-four, so a spec need not create them all.
  def genes_rise_experiment(skip: GENES_RISE_SKIP)
    definition = Lab::SWEEPS.fetch("genes_rise")
    create(:experiment, name: "Genes rise", slug: "genes-rise",
                        parents: definition[:parents].merge("skip_first" => skip),
                        **definition.slice(:param_grid, :seeds, :epochs, :priority))
  end

  GENES_RISE_SKIP = 1

  # `count` qualifying reach-cap128 runs past the `skip` the rule sets aside, which are created
  # first so they hold the lowest run ids; in run-id order.
  def genes_rise_parents(count: 1, skip: GENES_RISE_SKIP)
    experiment = Experiment.find_by(slug: "reach-cap128") || reach_cap128_experiment
    Array.new(skip + count) { reach_run(experiment, crossing: 500, shares: [0.0, 0.9, 0.9]) }.drop(skip)
  end

  # The children of one arm, `:count`, `:capped`, `:shadow` or `:drift`, in (parent, seed)
  # order.
  def genes_rise_children(experiment, treatment)
    experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed)
              .select { |run| Lab::GenesRiseReading.treatment_key(run.params) == treatment }
  end

  # A ramp from 10 at descent, one more every ten samples: a late rise with a new maximum
  # every 1 000 epochs. Bar 20, last-decile median 29.
  def genes_rise_ramp = ->(index) { 10 + (index / 10) }

  # 200 own samples 100 epochs apart from the parent epoch, the bundle's cadence: the settled
  # samples are 10–199, the fifth decile 86–104, the last decile 181–199 and the final quarter
  # 152–199, its first window 152–176 and its last 175–199. `classes` and `genes` read
  # `logic_depth_classes` and `genes_essential_held`, and `share` the replicator share, each a
  # value or a lambda of the index.
  def genes_rise_sample(run, classes: 1, genes: classes, share: 0.9, length: 2_000.0, status: "finished")
    insert_own_samples(run, Array.new(200) do |index|
      { "replicator_share" => genes_rise_at(share, index), "logic_depth_classes" => genes_rise_at(classes, index),
        "genes_essential_held" => genes_rise_at(genes, index), "logic_depth_max" => 10, "meta_len_mean" => length,
        "fidelity_p10" => 12, "fidelity_p50" => 14, "fidelity_p90" => 16, "repertoire_mean" => 120.5,
        "silent_share" => 0.05, "predation_rate" => 0.31, "predation_relation_rate" => 0.33 }
    end, every: 100)
    run.update!(status: status)
  end

  private

  def genes_rise_at(value, index) = value.respond_to?(:call) ? value.call(index) : value
end

RSpec.configure { |config| config.include GenesRiseRuns }
