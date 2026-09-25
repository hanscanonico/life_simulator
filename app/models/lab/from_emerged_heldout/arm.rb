# frozen_string_literal: true

module Lab
  module FromEmergedHeldout
    # One treatment's held-out children: the settled-relapse and extinction counts are where
    # a treatment that kills replicators shows, whatever its tests read.
    Arm = Data.define(:treatment, :children) do
      delegate :name, to: :treatment

      def finished_count = children.count(&:finished?)

      def settled_relapse_count = children.count { |child| child.heldout.settled_relapse_epoch }

      def extinct_count = children.count { |child| child.heldout.extinct }

      def latency_measured_count = children.count { |child| child.heldout.latency_measured? }

      def survivor_count = children.count { |child| child.heldout.survivor? }

      def cells
        [name, children.size, finished_count, settled_relapse_count, extinct_count, latency_measured_count,
         survivor_count]
      end
    end
  end
end
