# frozen_string_literal: true

module Lab
  module FromEmergedHeldout
    # One confirmatory hypothesis on one economy arm: its sign test over the held-out pairs
    # (a Lab::DescendantReading::Comparison, whose outcome :held reads "shown" here).
    Test = Data.define(:hypothesis, :treatment, :comparison) do
      delegate :outcome, to: :comparison

      def outcome_label = OUTCOME_LABELS.fetch(outcome)

      def badge_class = OUTCOME_BADGES.fetch(outcome)

      def cells
        [hypothesis, treatment.name, comparison.measured_count, comparison.favouring, comparison.against,
         comparison.ties, comparison.p_value&.to_f, outcome_label,
         comparison.carried_by.map { |parents| parents.join("+") }.join(" ").presence]
      end

      def agreement_cells
        comparison.agreement.map do |row|
          [hypothesis, treatment.name, row.parent_id, row.treatment, row.continuation, row.ties, row.unmeasured]
        end
      end
    end
  end
end
