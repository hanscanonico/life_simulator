# frozen_string_literal: true

module Lab
  module LogicReading
    # One confirmatory hypothesis: its sign test over the pairs of a treated arm against a
    # control arm (a Lab::DescendantReading::Comparison, whose outcome :held reads "shown").
    Test = Data.define(:hypothesis, :treatment, :control, :comparison) do
      delegate :outcome, to: :comparison

      def outcome_label = FromEmergedHeldout::OUTCOME_LABELS.fetch(outcome)

      def badge_class = FromEmergedHeldout::OUTCOME_BADGES.fetch(outcome)

      def cells
        [hypothesis, treatment.name, control.name, comparison.measured_count, comparison.favouring,
         comparison.against, comparison.ties, comparison.p_value&.to_f, outcome_label,
         comparison.carried_by.map { |parents| parents.join("+") }.join(" ").presence]
      end

      def agreement_cells
        comparison.agreement.map do |row|
          [hypothesis, treatment.name, control.name, row.parent_id, row.treatment, row.continuation, row.ties,
           row.unmeasured]
        end
      end
    end
  end
end
