# frozen_string_literal: true

module Lab
  module MetabolismReading
    Rung = Data.define(:task, :reached, :median_first_epoch)

    # One arm's children, counted: the settled-relapse and extinction counts are where an arm
    # that kills replicators shows, whatever its tests read, and the loop and stepping-stone
    # counts are the ladder's descriptive reading.
    Arm = Data.define(:treatment, :children) do
      delegate :name, to: :treatment

      # The descriptive ladder: per task, in ladder order, how many children's worlds held it
      # at TASK_PRESENT_SHARE and the median first epoch they did, nil where none did.
      def ladder
        TASKS.map do |task|
          epochs = children.filter_map { |child| child.metabolism.first_epochs[task] }
          Rung.new(task: task, reached: epochs.size, median_first_epoch: Findings::Median.of(epochs))
        end
      end

      def cells = [name, children.size, *ARM_COUNTS.map { |predicate| children.count(&predicate) }]
    end
  end
end
