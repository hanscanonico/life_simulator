# frozen_string_literal: true

module Lab
  module LocalityEmergenceReading
    # H-peak: radius PEAK_RADIUS emerges more often than each of PEAK_RIVALS. One one-sided
    # Fisher exact test per rival on emerged of finished, the family Holm-corrected. Shown
    # where both corrected p are below FAMILY_ALPHA; refuted where the peak arm's rate is at
    # most every rival's; not shown otherwise. Untested until each of the three arms has a
    # finished run.
    Peak = Data.define(:arms) do
      def peak_arm = arms.find { |arm| arm.radius == PEAK_RADIUS }

      def rival_arms = PEAK_RIVALS.filter_map { |radius| arms.find { |arm| arm.radius == radius } }

      def testable? = !peak_arm.nil? && rival_arms.size == PEAK_RIVALS.size && [peak_arm, *rival_arms].all?(&:finished?)

      def p_values
        return [] unless testable?

        rival_arms.map do |rival|
          Stats::FisherExact.greater([[peak_arm.emerged, peak_arm.finished - peak_arm.emerged],
                                      [rival.emerged, rival.finished - rival.emerged]])
        end
      end

      def adjusted_p_values = Stats::Holm.adjust(p_values)

      def shown? = testable? && adjusted_p_values.all? { |value| value < FAMILY_ALPHA.rationalize }

      def refuted? = testable? && rival_arms.all? { |rival| peak_arm.rate <= rival.rate }

      def outcome
        return :untested unless testable?
        return :shown if shown?
        return :refuted if refuted?

        :not_shown
      end

      def outcome_label = OUTCOME_LABELS.fetch(outcome)

      def badge_class = OUTCOME_BADGES.fetch(outcome)

      # One line per rival: the arm, both counts, the raw and the Holm-corrected p.
      def comparisons
        rival_arms.zip(p_values, adjusted_p_values).map do |rival, raw, adjusted|
          "#{peak_arm.label} #{peak_arm.emerged}/#{peak_arm.finished} against #{rival.label} " \
            "#{rival.emerged}/#{rival.finished}: one-sided Fisher p = #{format('%.5f', raw)}, " \
            "Holm #{format('%.5f', adjusted)}"
        end
      end

      def line
        return "H-peak #{outcome_label}: an arm of #{PEAK_RADIUS}, 1 or well-mixed has no finished run" unless testable?

        "H-peak #{outcome_label}; #{comparisons.join('; ')}"
      end
    end
  end
end
