# frozen_string_literal: true

# Deletion of pending runs, the only runs the lab may remove: a claimed or running run
# belongs to a runner and a terminal one carries a measurement. A pending run has no
# samples and no snapshots by construction, so one that does was written to and is not a
# pending run any more — either way the whole batch is refused rather than half deleted.
module DiscardsPendingRuns
  private

  def discard!(runs)
    discardable = runs.to_a
    refuse!(discardable.reject(&:pending?), "are not pending")
    refuse!(discardable.select { |run| measured?(run) }, "carry samples or snapshots")
    discardable.each(&:destroy!)
    discardable.map(&:id).sort
  end

  def refuse!(runs, reason)
    return if runs.empty?

    raise ArgumentError, "runs #{runs.map(&:id).sort.join(', ')} #{reason}: nothing discarded"
  end

  def measured?(run)
    run.samples.exists? || run.snapshots.exists?
  end
end
