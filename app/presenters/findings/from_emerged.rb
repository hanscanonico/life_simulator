# frozen_string_literal: true

module Findings
  # The from-emerged sweep's two pre-registered readings (DESIGN §1.3 item 11) as the two
  # findings that state them: the held-out H3-latency reading, rung 3, and the complexity
  # readings, rung 4. `report` is the sweep's Lab::DescendantReading::Report; every verdict,
  # count and p is its own, and this adds only the size of the latency effect the sign test
  # does not carry, as medians over the held-out children.
  class FromEmerged
    LATENCY = "H3-latency"
    SURVIVORS = "H4-survivors"

    # One treatment's held-out children whose latency ratio is measured: the median of their
    # first-decile and last-decile `copy_latency` medians and of their ratios, and how many
    # ratios fell below 1.
    LatencyEffect = Data.define(:name, :measured, :first_latency, :last_latency, :ratio, :falling)

    def self.build(report) = new(report)

    def initialize(report)
      @report = report
    end

    attr_reader :report

    delegate :heldout, :comparisons, :persistence, :interim?, to: :report
    delegate :any?, to: :heldout

    def latency_tests = tests_of(LATENCY)

    def survivor_tests = tests_of(SURVIVORS)

    def latency_shown? = latency_tests.any? && latency_tests.all? { |test| test.outcome == :held }

    # Whether any economy arm reads as keeping complexity rising, under either entry: the
    # original sign test where the arm does not relapse more, or H4-survivors.
    def complexity_rise_shown?
      comparisons.any? { |treatment, comparison| treatment.priced? && comparison.reading == :held } ||
        survivor_tests.any? { |test| test.outcome == :held }
    end

    # Whether the original rule reads no economy arm at all, because every one relapses
    # more often than the continuation.
    def economy_arms_unread?
      economy = comparisons.select { |treatment, _| treatment.priced? }.values
      economy.any? && economy.all?(&:kills?)
    end

    def heldout_parent_count = heldout.children.map(&:parent_id).uniq.size

    def latency_effects = @latency_effects ||= heldout.arms.map { |arm| latency_effect(arm) }

    def continuation_effect = latency_effects.find { |effect| effect.name == "continuation" }

    def economy_effects = latency_effects.select { |effect| effect.name.start_with?("economy") }

    # The parents whose pairs favour the treatment more often than the continuation.
    def parents_favouring(test) = test.comparison.agreement.count { |row| row.treatment > row.continuation }

    def claim_sentence
      treated = economy_effects.map { |effect| "#{format_ratio(effect.ratio)} under #{effect.name}" }.to_sentence
      sentence = "Over the held-out children, the median ratio of last-decile to first-decile copy_latency " \
                 "was #{treated}"
      return "#{sentence}." if continuation_effect.nil?

      "#{sentence}, against #{format_ratio(continuation_effect.ratio)} in the continuation."
    end

    private

    def tests_of(hypothesis) = heldout.tests.select { |test| test.hypothesis == hypothesis }

    def latency_effect(arm)
      readings = arm.children.map(&:heldout).select(&:latency_measured?)
      LatencyEffect.new(name: arm.name, measured: readings.size,
                        first_latency: Median.of(readings.map(&:first_latency)),
                        last_latency: Median.of(readings.map(&:last_latency)),
                        ratio: Median.of(readings.map(&:latency_ratio)),
                        falling: readings.count { |reading| reading.latency_ratio < 1 })
    end

    def format_ratio(ratio) = ratio.nil? ? "—" : Charts.format_value(ratio.to_f)
  end
end
