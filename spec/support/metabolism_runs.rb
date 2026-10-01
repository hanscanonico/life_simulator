# frozen_string_literal: true

# The metabolism sweep, its parents and its children's own samples, for the specs of its
# reading.
module MetabolismRuns
  def metabolism_experiment
    definition = Lab::SWEEPS.fetch("metabolism")
    create(:experiment, name: "Metabolism", slug: "metabolism",
                        **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end

  # A finished sweep-9 economy-off control whose last stored world reads mostly
  # replicators: a parent the sweep qualifies.
  def metabolism_parent
    params = Lab::Schema.run_defaults.merge("energy_influx" => 0, "steal_amount" => 0, "max_tape_len" => 128,
                                            "energy_stock_cap" => 4 * (2**13), "steal_loss" => 0.5,
                                            "tape_len" => 64, "mutation_rate" => Lab::EMERGENT_MUTATION_RATE)
    source = Experiment.find_by(slug: "host-parasite") || create(:experiment, slug: "host-parasite")
    run = create(:run, :emerged, experiment: source, params: params, status: "finished", epochs: 1_000,
                                 emergence_epoch: 400)
    create(:snapshot, run: run, epoch: run.epochs)
    create(:snapshot_reading, run: run, epoch: run.epochs, source_epoch: run.epochs,
                              values: { "replicator_share" => 0.9 })
    run
  end

  def metabolism_children(experiment, reward:)
    experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed)
              .select { |run| Lab::MetabolismReading.metabolism_run?(run.params) == reward }
  end

  # 200 own samples 10 epochs apart from the parent epoch 1 000, so the last 100 are past
  # the settling window and its last decile is the last 10. The task capabilities read
  # `capability` and `loop` there and 0 before; the dominant replicator's instruction count
  # reads `first_count` until then and `last_count` there. `share` and `task_shares` may be
  # a value or a lambda of the sample's index.
  def metabolism_sample(run, status: "finished", **options)
    insert_own_samples(run, Array.new(200) { |index| metabolism_values(index, **options) })
    run.update!(status: status)
  end

  private

  def metabolism_values(index, capability: 0, loop: 0, first_count: 100, last_count: 100, share: 0.9,
                        task_shares: {})
    last = index >= 190
    shares = Lab::MetabolismReading::TASKS.to_h do |task|
      [Lab::MetabolismReading.share_key(task), at(task_shares.fetch(task, 0.0), index)]
    end
    { "replicator_share" => at(share, index), "dominant_self_replicates" => true,
      "dominant_instruction_count" => last ? last_count : first_count,
      "task_capability" => last ? capability : 0, "task_capability_loop" => last ? loop : 0,
      "dominant_tasks" => 1, "dominant_task_count" => 1, "copy_latency" => 1_000, **shares }
  end

  def at(value, index) = value.respond_to?(:call) ? value.call(index) : value
end

RSpec.configure { |config| config.include MetabolismRuns }
