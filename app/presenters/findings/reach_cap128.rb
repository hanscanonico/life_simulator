# frozen_string_literal: true

module Findings
  # The claim the reach-cap128 finding states (DESIGN §1.3 sweep 14), composed from the
  # sweep's pre-registered reading, a Lab::ReachCap128Reading::Report. Every count, median,
  # verdict and p here is the report's; this only names the two arms and the ratio of their
  # rates the page states.
  class ReachCap128
    def self.build(report) = new(report)

    def initialize(report)
      @report = report
    end

    attr_reader :report

    delegate :comparison, :interim?, to: :report
    delegate :treatment, :control, :p_value, to: :comparison

    def any? = report.arms.any? { |arm| arm.rows.any? }

    def shown? = comparison.outcome == :shown

    # How many times the control's rate radius 4's is, nil while either arm has no count or
    # the control emerged nowhere.
    def rate_ratio
      return nil unless comparison.testable? && control.rate.positive?

      treatment.rate / control.rate
    end

    def claim_sentence
      return unshown_sentence unless shown?

      "With room to grow, #{treatment.label} emerged in #{of(treatment)} worlds, against " \
        "#{of(control)} in the radius-1 control#{ratio_clause}."
    end

    def of(arm) = "#{arm.emerged} of #{arm.counted}"

    private

    def ratio_clause = rate_ratio ? ": #{format('%.1f', rate_ratio)} times the rate" : ""

    def unshown_sentence
      "The pre-registered reading does not show the reach effect on growable tapes: " \
        "H-reach128 #{comparison.outcome_label}."
    end
  end
end
