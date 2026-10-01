# frozen_string_literal: true

# The logic sweep and its children's own samples, for the specs of its reading. Its parents
# are the metabolism sweep's (MetabolismRuns#metabolism_parent).
module LogicRuns
  def logic_experiment
    definition = Lab::SWEEPS.fetch("logic")
    create(:experiment, name: "Logic", slug: "logic",
                        **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end

  # The children of one arm, `:full`, `:deep_only` or `:none`, in (parent, seed) order.
  def logic_children(experiment, treatment)
    experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed)
              .select { |run| Lab::LogicReading.treatment_key(run.params) == treatment }
  end

  # 200 own samples 10 epochs apart from the parent epoch 1 000, so the last 100 are past
  # the settling window and its last decile is the last 10. The logic capabilities read
  # `capability` and `deep` there and 0 before; the dominant replicator's instruction count
  # reads `first_count` until then and `last_count` there. `share` and `task_shares` may be
  # a value or a lambda of the sample's index.
  def logic_sample(run, status: "finished", **options)
    insert_own_samples(run, Array.new(200) { |index| logic_values(index, **options) })
    run.update!(status: status)
  end

  private

  def logic_values(index, capability: 0, deep: 0, first_count: 100, last_count: 100, share: 0.9, task_shares: {})
    last = index >= 190
    shares = Lab::LogicReading::TASKS.to_h do |task|
      [Lab::LogicReading.share_key(task), logic_at(task_shares.fetch(task, 0.0), index)]
    end
    { "replicator_share" => logic_at(share, index), "dominant_self_replicates" => true,
      "dominant_instruction_count" => last ? last_count : first_count,
      "logic_capability" => last ? capability : 0, "logic_capability_deep" => last ? deep : 0,
      "dominant_logic_tasks" => 1, "dominant_logic_task_count" => 1, "copy_latency" => 1_000, **shares }
  end

  def logic_at(value, index) = value.respond_to?(:call) ? value.call(index) : value
end

RSpec.configure { |config| config.include LogicRuns }
