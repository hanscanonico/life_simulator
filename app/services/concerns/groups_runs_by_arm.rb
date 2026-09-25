# frozen_string_literal: true

# The arm an experiment's run belongs to, named the way the sweep's phase diagram names it,
# and the block of runs something has been sampled from — the shape every arm-by-arm
# reading of a sweep is built on, so the detector block and the complexity reading group
# and label identically.
#
# The host supplies a private `experiment` and an `arm(label, runs)` that builds its own
# arm from a label and the runs carrying it.
module GroupsRunsByArm
  private

  def arms_of(runs) = runs.group_by { |run| arm_label(run) }.map { |label, arm_runs| arm(label, arm_runs) }

  def arm_label(run)
    labels = axes.filter_map { |axis| axis.label_of_run(run.params) }

    labels.empty? ? experiment.slug : labels.join(" ")
  end

  def axes = @axes ||= Experiments::Axis.sweep(experiment.param_grid)

  # A run nothing has been sampled from yet is no row: an arm-by-arm reading is a reading
  # of stored samples, not of the queue. One index probe per run: a DISTINCT over the
  # sweep's samples read every one of them, 4 s at the host-parasite sweep's 2.5 M.
  def sampled_run_ids
    @sampled_run_ids ||= experiment.runs.where(Sample.where("samples.run_id = runs.id").arel.exists).pluck(:id)
  end
end
