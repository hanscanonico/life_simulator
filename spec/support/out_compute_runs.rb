# frozen_string_literal: true

# The out-compute sweep, its parents in the reach-cap128 sweep and its children's own samples,
# for the specs of its builder and its reading.
module OutComputeRuns
  def out_compute_experiment
    definition = Lab::SWEEPS.fetch("out_compute")
    create(:experiment, name: "Out-compute", slug: "out-compute",
                        **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end

  # `count` reach-cap128 runs that emerged and whose terminal world (epoch 2 000) is nearly
  # all replicators, so each qualifies as an out-compute parent; in run-id order.
  def out_compute_parents(count: 1)
    experiment = Experiment.find_by(slug: "reach-cap128") || reach_cap128_experiment
    Array.new(count) { reach_run(experiment, crossing: 500, shares: [0.0, 0.9, 0.9]) }
  end

  # The children of one arm, `:out_compute`, `:equal`, `:shadow` or `:none`, in (parent,
  # seed) order.
  def out_compute_children(experiment, treatment)
    experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed)
              .select { |run| Lab::OutComputeReading.treatment_key(run.params) == treatment }
  end

  # 200 own samples 10 epochs apart from the parent epoch, as ToplessRiseRuns#topless_rise_sample
  # lays them out: the fifth decile is samples 140–149 and the last 190–199.
  # `logic_depth_max` reads `fifth` until the last decile and `last` there, unless `depth` gives
  # it per sample index; `logic_depth_classes` reads `classes_fifth` and `classes_last` the
  # same way; `share` may be a value or a lambda of the index.
  def out_compute_sample(run, fifth: 2, last: fifth, depth: nil, classes_fifth: 3, classes_last: classes_fifth,
                         share: 0.9, status: "finished")
    depths = depth || ->(index) { index >= 190 ? last : fifth }
    insert_own_samples(run, Array.new(200) do |index|
      { "replicator_share" => out_compute_at(share, index), "logic_depth_max" => out_compute_at(depths, index),
        "logic_depth_classes" => index >= 190 ? classes_last : classes_fifth, "repertoire_mean" => 2.5,
        "silent_share" => 0.1, "predation_rate" => 0.29, "predation_relation_rate" => 0.32 }
    end)
    run.update!(status: status)
  end

  private

  def out_compute_at(value, index) = value.respond_to?(:call) ? value.call(index) : value
end

RSpec.configure { |config| config.include OutComputeRuns }
