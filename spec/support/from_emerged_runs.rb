# frozen_string_literal: true

# The from-emerged sweep, its parents and its children's own samples, for the specs of the
# findings that read it.
module FromEmergedRuns
  def from_emerged_experiment
    definition = Lab::SWEEPS.fetch("from_emerged")
    create(:experiment, name: "From an emerged world", slug: "from-emerged",
                        **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end

  # A finished sweep-9 economy-off control at `seed` whose last stored world reads mostly
  # replicators: a parent the sweep qualifies. A seed above 90 makes it a held-out parent.
  def from_emerged_parent(seed:)
    params = Lab::Schema.run_defaults.merge("energy_influx" => 0, "steal_amount" => 0, "max_tape_len" => 128,
                                            "energy_stock_cap" => 4 * (2**13), "steal_loss" => 0.5,
                                            "tape_len" => 64, "mutation_rate" => Lab::EMERGENT_MUTATION_RATE)
    source = Experiment.find_by(slug: "host-parasite") || create(:experiment, slug: "host-parasite")
    run = create(:run, :emerged, experiment: source, params: params, status: "finished", epochs: 1_000,
                                 emergence_epoch: 400, seed: seed)
    create(:snapshot, run: run, epoch: run.epochs)
    create(:snapshot_reading, run: run, epoch: run.epochs, source_epoch: run.epochs,
                              values: { "replicator_share" => 0.9 })
    run
  end

  # The children of `experiment` under the treatment at `index` of its grid.
  def from_emerged_children(experiment, index)
    bundle = experiment.param_grid.fetch("treatment")[index]
    experiment.runs.order(:parent_run_id, :seed).select do |run|
      Experiments::Axis.sweep(experiment.param_grid).first.value_of(run.params) == bundle
    end
  end

  # 200 own samples 10 epochs apart, so the last 100 are past the settling window: a steady
  # share, a self-replicating dominant tape whose instruction count reads `first_count` then
  # `last_count` over its last decile, and `copy_latency` reading `first` then `last` there.
  def from_emerged_sample(run, first: 4_000, last: 4_000, first_count: 100, last_count: 100)
    insert_own_samples(run, Array.new(200) do |index|
      last_decile = index >= 180
      { "replicator_share" => 0.9, "dominant_self_replicates" => true,
        "dominant_instruction_count" => last_decile ? last_count : first_count,
        "copy_latency" => index >= 190 ? last : first }
    end)
    run.update!(status: "finished")
  end
end

RSpec.configure { |config| config.include FromEmergedRuns }
