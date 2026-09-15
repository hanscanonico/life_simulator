# frozen_string_literal: true

module Findings
  # The sentence printed under a sweep's emergence-rate table, built from that sweep's own
  # counts: which treated arms emerged more or less often than the control arm, and whether
  # any of those differences reaches the conventional threshold. The same object serves all
  # three sweeps, so nothing here names a substrate, and it never reads a difference as
  # established that the p-values leave open.
  class EmergenceReading
    NO_CONTROL = "No run of the control arm has reached its last epoch, so how often life " \
                 "emerged under this substrate cannot be compared yet."

    def initialize(bet:)
      @bet = bet
    end

    def sentence
      return NO_CONTROL unless bet.control_tested?
      return alone if tested_arms.empty?

      "#{direction}; #{significance}."
    end

    private

    attr_reader :bet

    def tested_arms = bet.tested_treated_arms

    def significant_arms = tested_arms.select { |arm| bet.emergence_significant?(arm) }

    def control_fraction = bet.control_arm.emergence_fraction

    def control_rate = bet.control_arm.emergence_rate

    def alone
      "No treated arm has a run that reached its last epoch, so the control arm's " \
        "#{control_fraction} stands alone and nothing can be compared yet."
    end

    def direction
      return higher_direction if higher_arms.any?
      return "Every treated arm emerged less often than the control arm (#{against(tested_arms)})" if all_lower?

      "No treated arm emerged more often than the control arm (#{against(tested_arms)})"
    end

    def higher_direction
      clause = "#{labels(higher_arms)} emerged more often than the control arm (#{against(higher_arms)})"
      rest = tested_arms - higher_arms
      return clause if rest.empty?

      "#{clause}, and #{labels(rest)} no more often (#{fractions(rest)})"
    end

    def significance
      threshold = format("p < %.2f", Findings::OpenEndednessSurvey::SIGNIFICANCE)
      return "none of the differences reaches #{threshold}" if significant_arms.empty?
      return "the difference at #{labels(significant_arms)} reaches #{threshold}" if significant_arms.one?

      "the differences at #{labels(significant_arms)} reach #{threshold}"
    end

    def higher_arms = tested_arms.select { |arm| arm.emergence_rate > control_rate }

    def all_lower? = tested_arms.all? { |arm| arm.emergence_rate < control_rate }

    def against(arms) = "#{fractions(arms)} against #{control_fraction}"

    def fractions(arms) = joined(arms.map(&:emergence_fraction))

    def labels(arms) = joined(arms.map(&:label))

    def joined(parts) = parts.to_sentence(last_word_connector: " and ", two_words_connector: " and ")
  end
end
