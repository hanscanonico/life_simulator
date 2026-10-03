# frozen_string_literal: true

module Lab
  module ToplessRiseReading
    # One arm's children, counted: extinction and relapse show where an arm kills
    # replicators, and the ceilinged count where the ladder had a near top after all.
    Arm = Data.define(:treatment, :children) do
      delegate :name, to: :treatment

      def cells = [name, children.size, *ARM_COUNTS.map { |predicate| children.count(&predicate) }]
    end
  end
end
