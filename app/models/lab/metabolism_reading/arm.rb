# frozen_string_literal: true

module Lab
  module MetabolismReading
    # One arm's children, counted: the settled-relapse and extinction counts are where an arm
    # that kills replicators shows, whatever its tests read, and the loop and stepping-stone
    # counts are the ladder's descriptive reading.
    Arm = Data.define(:treatment, :children) do
      delegate :name, to: :treatment

      def cells = [name, children.size, *ARM_COUNTS.map { |predicate| children.count(&predicate) }]
    end
  end
end
