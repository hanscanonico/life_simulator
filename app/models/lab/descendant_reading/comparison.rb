# frozen_string_literal: true

module Lab
  module DescendantReading
    # One treated arm read against the continuation over (parent, seed) pairs: H-economy for
    # a priced arm, H-host for the host arm. Only pairs whose two children are both measured
    # enter the test; a pair is discordant when exactly one of its children rises.
    #
    # A treated arm whose children relapse more often than the continuation's is killing
    # replicators, so its test is printed but not read as the hypothesis (`kills`).
    class Comparison
      Pair = Data.define(:parent_id, :seed, :treated, :control) do
        def measured? = treated&.measured? && control&.measured?

        def favours_treatment? = measured? && treated.rises? && !control.rises?

        def favours_continuation? = measured? && control.rises? && !treated.rises?
      end

      # How one parent's pairs fell: the entry's per-parent agreement, with the pairs not
      # both measured counted apart from the ties.
      Agreement = Data.define(:parent_id, :treatment, :continuation, :ties, :unmeasured)

      READING_LABELS = { held: "held", not_shown: "not shown", refuted: "refuted", no_pairs: "no measured pairs",
                         kills: "not read: relapses more than the continuation" }.freeze
      READING_BADGES = { held: "badge-success", not_shown: "badge-warning", refuted: "badge-error",
                         no_pairs: "badge-info", kills: "badge-error" }.freeze

      def initialize(pairs:, kills:)
        @pairs = pairs
        @kills = kills
      end

      attr_reader :pairs

      def kills? = @kills

      def measured_count = measured.size

      def favouring = measured.count(&:favours_treatment?)

      def against = measured.count(&:favours_continuation?)

      def ties = measured_count - favouring - against

      def p_value = p_value_of(measured)

      # :held, :not_shown, :refuted, or :no_pairs where no pair is measured on both sides.
      def outcome = outcome_of(measured)

      # What the hypothesis reads: the outcome, unless the arm kills replicators.
      def reading = kills? ? :kills : outcome

      def reading_label = READING_LABELS.fetch(reading)

      def outcome_label = READING_LABELS.fetch(outcome)

      def badge_class = READING_BADGES.fetch(reading)

      def agreement
        pairs.group_by(&:parent_id).map do |parent_id, parent_pairs|
          measured_pairs = parent_pairs.select(&:measured?)
          favouring = measured_pairs.count(&:favours_treatment?)
          against = measured_pairs.count(&:favours_continuation?)
          Agreement.new(parent_id: parent_id, treatment: favouring, continuation: against,
                        ties: measured_pairs.size - favouring - against,
                        unmeasured: parent_pairs.size - measured_pairs.size)
        end
      end

      # Every minimal set of up to LEAVE_OUT_PARENTS parents whose pairs left out drop a held
      # test to p at or above the level: the parents the result rests on. A set holding a
      # smaller carrying set is not listed again. Empty for a test that did not hold.
      def carried_by
        return [] unless outcome == :held

        parent_ids = measured.map(&:parent_id).uniq
        (1..LEAVE_OUT_PARENTS).each_with_object([]) do |size, carriers|
          parent_ids.combination(size).each do |left_out|
            next if carriers.any? { |carrier| (carrier - left_out).empty? }

            carriers << left_out if falls_without?(left_out)
          end
        end
      end

      private

      def measured = @measured ||= pairs.select(&:measured?)

      def falls_without?(left_out)
        rest = measured.reject { |pair| left_out.include?(pair.parent_id) }
        p = p_value_of(rest)
        p.nil? || p >= SIGN_TEST_LEVEL.rationalize
      end

      def p_value_of(measured_pairs)
        Stats::SignTest.one_sided(favouring: measured_pairs.count(&:favours_treatment?),
                                  against: measured_pairs.count(&:favours_continuation?))
      end

      def outcome_of(measured_pairs)
        return :no_pairs if measured_pairs.empty?

        favouring = measured_pairs.count(&:favours_treatment?)
        return :refuted if favouring <= measured_pairs.count(&:favours_continuation?)

        p_value_of(measured_pairs) < SIGN_TEST_LEVEL.rationalize ? :held : :not_shown
      end
    end
  end
end
