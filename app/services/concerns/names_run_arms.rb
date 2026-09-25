# frozen_string_literal: true

# The arm an experiment's run belongs to, named so it stands on its own in an export read
# away from the sweep's tables ("radius 2", "well-mixed"), which the bare labels
# GroupsRunsByArm gives the phase diagram would not.
#
# The host supplies a private `experiment`.
module NamesRunArms
  private

  def arm_label(run)
    labels = axes.filter_map { |axis| axis.named_label_of_run(run.params) }

    labels.empty? ? experiment.slug : labels.join(" ")
  end

  def axes = @axes ||= Experiments::Axis.sweep(experiment.param_grid)
end
