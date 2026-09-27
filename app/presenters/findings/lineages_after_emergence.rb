# frozen_string_literal: true

module Findings
  # The claim the lineage-diversity finding states (DESIGN §1.3 sweep 12), composed from the
  # sweep's pre-registered reading, a Lab::LineageDiversityReading::Report. Every verdict,
  # count and p here is the report's; this puts them into sentences and adds the one
  # descriptive number the report does not carry, the exact test of emergence against reach.
  class LineagesAfterEmergence
    # One arm's emergence: finished runs, those with a confirmed crossing, and those the
    # share clause kept, against the radius sweep's count at the same radius.
    Emergence = Data.define(:label, :finished, :crossed, :emerged, :radius_emerged, :radius_finished) do
      def share_failed = crossed - emerged

      def radius_sweep? = !radius_finished.nil?
    end

    def self.build(report) = new(report)

    def initialize(report)
      @report = report
    end

    attr_reader :report

    delegate :arms, :hypothesis, :final, :interim?, to: :report
    delegate :any?, to: :arms

    def measured = arms.flat_map(&:measured)

    def verdict_count(verdict) = measured.count { |row| row.reading.verdict == verdict }

    def between_rows = measured.select { |row| row.reading.verdict == :between }

    def claim_sentence
      mono = verdict_count(:monophyletic)
      between = verdict_count(:between)
      rest = "#{mono} read monophyletic and #{between} between, and the median effective number of " \
             "lineages is #{medians_phrase}"
      poly = verdict_count(:polyphyletic)
      return "No emerged world stayed polyphyletic: of the #{measured.size} measured, #{rest}." if poly.zero?

      "#{poly} of the #{measured.size} measured emerged worlds stayed polyphyletic; #{rest}."
    end

    def emergence = @emergence ||= arms.map { |arm| emergence_of(arm) }

    def emerged_total = emergence.sum(&:emerged)

    def finished_total = emergence.sum(&:finished)

    # Descriptive only: the sweep was not designed to test emergence against reach.
    def emergence_p
      @emergence_p ||= Stats::FreemanHalton.p_value(emergence.map { |arm| [arm.emerged, arm.finished - arm.emerged] })
    end

    private

    def medians_phrase
      medians = arms.select(&:read?).map { |arm| [arm.label, arm.effective_count] }
      values = medians.map(&:last).uniq
      return "#{format_count(values.first)} in every read arm" if values.one?

      medians.map { |label, value| "#{format_count(value)} at #{label}" }.to_sentence
    end

    def format_count(value) = value.nil? ? "—" : Charts.format_value(value.to_f)

    def emergence_of(arm)
      Emergence.new(label: arm.label, finished: arm.finished.size,
                    crossed: arm.finished.count { |row| row.emergence_epoch.present? }, emerged: arm.emerged.size,
                    radius_emerged: arm.radius_emerged, radius_finished: arm.radius_finished)
    end
  end
end
