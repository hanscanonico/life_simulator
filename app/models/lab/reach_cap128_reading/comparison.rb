# frozen_string_literal: true

module Lab
  module ReachCap128Reading
    # H-reach128: radius 4 at cap 128 emerges more often than sweep 9's cap-128 control at
    # radius 1. One one-sided Fisher exact test on emerged of counted: shown at p below
    # LEVEL; refuted where radius 4's rate is at most the control's; not shown otherwise.
    # Untested until each arm has a counted run.
    Comparison = Data.define(:treatment, :control) do
      def testable? = treatment.counted? && control.counted?

      def p_value
        return nil unless testable?

        Stats::FisherExact.greater([[treatment.emerged, treatment.counted - treatment.emerged],
                                    [control.emerged, control.counted - control.emerged]])
      end

      def outcome
        return :untested unless testable?
        return :shown if p_value < LEVEL.rationalize
        return :refuted if treatment.rate <= control.rate

        :not_shown
      end

      def outcome_label = OUTCOME_LABELS.fetch(outcome)

      def badge_class = OUTCOME_BADGES.fetch(outcome)

      def counts
        "#{treatment.label} #{treatment.emerged}/#{treatment.counted} against " \
          "#{control.label} #{control.emerged}/#{control.counted}"
      end

      def line
        return "H-reach128 #{outcome_label}: an arm has no counted run" unless testable?

        "H-reach128 #{outcome_label}; #{counts}: one-sided Fisher p = #{format('%.5f', p_value)}"
      end
    end
  end
end
