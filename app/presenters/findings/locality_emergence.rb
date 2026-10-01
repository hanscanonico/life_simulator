# frozen_string_literal: true

module Findings
  # The claim the locality-emergence finding states (DESIGN §1.3 sweep 13), composed from the
  # sweep's pre-registered reading, a Lab::LocalityEmergenceReading::Report. Every verdict,
  # count and p here is the report's. Beside it sits sweep 12's worlds read by the same
  # emergence rule, the exploratory counts the sweep was registered to confirm, so the page
  # can show that the two are different worlds even where their totals agree.
  class LocalityEmergence
    # One arm: its finished runs, those with a confirmed crossing and those the share clause
    # kept, with the exploratory sweep's arm at the same radius where it ran one.
    Arm = Data.define(:radius, :label, :finished, :crossed, :emerged, :rate, :exploratory) do
      def exploratory? = !exploratory.nil?

      def same_total? = exploratory? && exploratory.emerged == emerged && exploratory.finished == finished
    end

    def self.build(report, exploratory: nil) = new(report, exploratory)

    def initialize(report, exploratory)
      @report = report
      @exploratory = exploratory
    end

    attr_reader :report

    delegate :peak, :shape, :final, :interim?, to: :report

    def any? = report.arms.any?

    def shown? = peak.shown? && shape.shown?

    def arms = @arms ||= report.arms.map { |arm| arm_of(arm, exploratory_arms[arm.radius]) }

    def claim_sentence
      return unshown_sentence unless shown?

      top = peak.peak_arm
      rivals = peak.rival_arms.map { |arm| "#{arm.emerged} of #{arm.finished} #{where(arm)}" }
      "Emergence peaks at an intermediate reach: #{top.label} emerged in #{top.emerged} of " \
        "#{top.finished} fresh worlds, against #{rivals.to_sentence}, and the curve fitted over " \
        "the finite radii peaks at radius #{format('%.2f', shape.peak)}."
    end

    def exploratory? = arms.any?(&:exploratory?)

    def same_total_arms = arms.select(&:same_total?)

    def seed_range = seed_range_of(report.rows)

    def exploratory_seed_range = @exploratory && seed_range_of(@exploratory.rows)

    private

    def unshown_sentence
      "The pre-registered reading shows no peak: H-peak #{peak.outcome_label}, H-shape #{shape.outcome_label}."
    end

    def where(arm) = arm.radius == Lab::LocalityEmergenceReading::WELL_MIXED ? arm.label : "at #{arm.label}"

    def exploratory_arms
      return {} if @exploratory.nil?

      @exploratory_arms ||= @exploratory.arms.to_h { |arm| [arm.radius, arm_of(arm, nil)] }
    end

    def arm_of(arm, exploratory)
      Arm.new(radius: arm.radius, label: arm.label, finished: arm.finished,
              crossed: arm.rows.count { |row| row.finished? && row.emergence_epoch.present? },
              emerged: arm.emerged, rate: arm.rate, exploratory: exploratory)
    end

    def seed_range_of(rows)
      low, high = rows.map(&:seed).minmax
      low && (low..high)
    end
  end
end
