# frozen_string_literal: true

# The meta-stack sweep, its twins in the logic sweep and its children's own samples, for the
# specs of its reading. Its parents are the metabolism sweep's (MetabolismRuns#metabolism_parent).
module MetaStackRuns
  def meta_stack_experiment
    definition = Lab::SWEEPS.fetch("meta_stack")
    create(:experiment, name: "Meta-stack", slug: "meta-stack",
                        **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end

  # The children of one arm of either sweep, in (parent, seed) order.
  def meta_stack_children(experiment, treatment)
    experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed)
              .select { |run| Lab::MetaStackReading.treatment_key(run.params) == treatment }
  end

  # LogicRuns#logic_sample's 200 own samples, with the metabolism tape's descriptive keys
  # set throughout to `meta`.
  def meta_stack_sample(run, status: "finished", meta: {}, **options)
    insert_own_samples(run, Array.new(200) { |index| logic_values(index, **options).merge(meta) })
    run.update!(status: status)
  end
end

RSpec.configure { |config| config.include MetaStackRuns }
