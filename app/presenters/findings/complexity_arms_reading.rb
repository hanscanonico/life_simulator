# frozen_string_literal: true

module Findings
  # The claim a finding states on a sweep read arm by arm for rising complexity — DESIGN
  # §1.3 sweeps 9 and 10 — where every treated arm stands beside a control arm at the same
  # tape cap: which arms keep rising, how often life emerged against that control, whether
  # theft evolved, and what the pre-registered rule read.
  #
  # Every per-arm reading is `Experiments::ComplexityArmsService`'s and is never re-derived
  # here: this composes the service's arms into sentences. The sweep names its controls
  # through a predicate on run params and its arms through two nouns, so the same object
  # serves the economy-off controls of sweep 9 and the concat controls of sweep 10.
  class ComplexityArmsReading
    include GroupsRunsByArm
    include ArmsProse

    PAIRED_BY = "max_tape_len"

    MIN_ARM_RUNS = Experiments::ComplexityArmsService::MIN_ARM_RUNS

    VERDICT_BADGES = { pending: "badge-info", unresolved: "badge-info", keeps_rising: "badge-warning",
                       mostly_rising: "badge-success", refuted: "badge-error", not_rising: "badge-error",
                       barren: "badge-error" }.freeze

    # One arm of the sweep: how often life emerged in it, paired with the service's
    # complexity reading of the same label. An arm the service publishes no row for has no
    # measured run, no blank block and no steal op, so it reads unread.
    Arm = Data.define(:label, :params, :control, :terminal_count, :emerged_count, :complexity) do
      def control? = control

      def cap = params[PAIRED_BY]

      def reading = complexity&.reading || :unread

      def barren? = reading == :barren

      def measured_count = complexity&.measured_count.to_i

      def rising_count = complexity&.rising_count.to_i

      def plateau_count = complexity&.plateau_count.to_i

      def lineages = complexity&.lineages

      def tested? = terminal_count.positive?

      def unemerged_count = [terminal_count - emerged_count, 0].max

      def emergence_rate = tested? ? emerged_count.fdiv(terminal_count) : nil

      def emergence_fraction = "#{emerged_count} of #{terminal_count}"
    end

    def self.build(experiment:, complexity_arms:, control:, treated_name:, control_name:)
      new(experiment: experiment, complexity_arms: complexity_arms, control: control,
          treated_name: treated_name, control_name: control_name)
    end

    def initialize(experiment:, complexity_arms:, control:, treated_name:, control_name:)
      @experiment = experiment
      @complexity_arms = complexity_arms
      @control = control
      @treated_name = treated_name
      @control_name = control_name
    end

    attr_reader :complexity_arms, :treated_name, :control_name

    def arms = @arms ||= arms_of(sampled_runs)

    delegate :any?, to: :arms

    def controls = arms.select(&:control?)

    def treated = arms.reject(&:control?)

    def control_for(arm) = controls.find { |candidate| candidate.cap == arm.cap }

    def rising_arms = treated.select { |arm| arm.reading == :keeps_rising }

    # No treated arm held a replicator, so none has a plateau to set against its control's
    # and the refutation condition cannot be evaluated either way.
    def every_treated_barren? = treated.any? && treated.all?(&:barren?)

    def verdict
      return :pending if treated.empty?
      return :barren if every_treated_barren?
      return rising_verdict if rising_arms.any?
      return :unresolved if treated.any? { |arm| arm.reading == :unread }

      refutation_met? ? :refuted : :not_rising
    end

    def verdict_label
      case verdict
      when :keeps_rising, :mostly_rising then "keeps rising in #{rising_arms.size} of #{treated.size} arms"
      when :not_rising then "no arm keeps rising"
      when :pending then "no reading yet"
      when :barren then "no #{treated_name} held a replicator"
      else verdict.to_s
      end
    end

    def badge_class = VERDICT_BADGES.fetch(verdict)

    delegate :headline, :rising_notes, :refutation_sentence, :refutation_met?, :lineages_sentence,
             :control_readings_sentence, to: :prose

    def emergence_p_value(arm)
      paired = control_for(arm)
      return nil if arm.control? || paired.nil? || !arm.tested? || !paired.tested?

      Stats::FisherExact.two_sided([[arm.emerged_count, arm.unemerged_count],
                                    [paired.emerged_count, paired.unemerged_count]])
    end

    def emergence_significant?(arm)
      p_value = emergence_p_value(arm)

      p_value.present? && p_value < OpenEndednessSurvey::SIGNIFICANCE
    end

    def emergence_sentence
      compared = treated.select { |arm| emergence_p_value(arm) }
      return "No #{treated_name} has been run to an end beside a #{control_name} at its cap yet." if compared.empty?

      "#{emergence_direction(compared)}; #{significance(compared)}.#{barren_sentence}"
    end

    # Every treated arm's runs against every control's, both caps together. Descriptive
    # only: the pre-registered comparison is the per-cap one.
    def pooled_emergence_sentence
      treated_terminal, control_terminal = [treated, controls].map { |arms| arms.sum(&:terminal_count) }
      return nil if treated_terminal.zero? || control_terminal.zero?

      treated_emerged, control_emerged = [treated, controls].map { |arms| arms.sum(&:emerged_count) }
      p_value = Stats::FisherExact.two_sided([[treated_emerged, treated_terminal - treated_emerged],
                                              [control_emerged, control_terminal - control_emerged]])

      "#{treated_emerged} of #{treated_terminal} runs of the #{treated_name.pluralize} " \
        "emerged against #{control_emerged} of #{control_terminal} of the #{control_name.pluralize} " \
        "(two-sided Fisher exact p = #{format_p(p_value)})."
    end

    def steal_arms = complexity_arms.select(&:steals)

    def steal_arms? = steal_arms.any?

    def theft_sentence
      evolved = steal_arms.select { |arm| arm.theft == :evolved }
      peaks = evolved.map(&:peak_steal_rate)
      lead = "Theft #{theft_share(evolved.size, steal_arms.size)}"
      lead += ", peak steal_rate #{range_of(peaks)}" if peaks.any?

      "#{lead}. #{theft_null_sentence}"
    end

    # Every emerged run, the ones in arms the complexity reading publishes no row for
    # included: an arm whose emerged runs are all unmeasured still has them to account for.
    def emerged_count = sampled_runs.count(&:emerged?)

    # The emerged runs the pre-registered rule read no ratio on: those unmeasured under the
    # amended rule too, and the measured ones it would have dropped for a core at zero.
    def pre_registered_unmeasured_count
      emerged_count - complexity_arms.sum { |arm| pre_registered_measured_count(arm) }
    end

    def pre_registered_readable_arms
      complexity_arms.select { |arm| pre_registered_measured_count(arm) >= MIN_ARM_RUNS }
    end

    def pre_registered_sentence
      count = pre_registered_readable_arms.size
      arms_clause = count.zero? ? "no arm reads" : "#{counted(count, 'arm')} #{verb_for(count, %w[reads read])}"

      "Under the pre-registered rule #{pre_registered_unmeasured_count} of the #{emerged_count} emerged runs " \
        "are unmeasured and #{arms_clause}."
    end

    def treated_rising_count = treated.sum(&:rising_count)

    def treated_measured_count = treated.sum(&:measured_count)

    def control_rising_count = controls.sum(&:rising_count)

    def control_measured_count = controls.sum(&:measured_count)

    private

    attr_reader :experiment, :control

    def prose = @prose ||= ComplexityArmsHeadline.new(reading: self)

    def arm(label, runs)
      terminal = runs.select(&:terminal?)

      Arm.new(label: label, params: runs.first.params, control: control.call(runs.first.params),
              terminal_count: terminal.size, emerged_count: terminal.count(&:emerged?),
              complexity: complexity_arms.find { |reading| reading.label == label })
    end

    # A run that reported no sample never ran a world anyone can read, the same runs the
    # complexity reading leaves out.
    def sampled_runs
      return [] unless experiment

      @sampled_runs ||= experiment.runs.where("EXISTS (SELECT 1 FROM samples WHERE samples.run_id = runs.id)")
                                  .order(:id).select(:id, :params, :status, :emergence_epoch).to_a
    end

    def rising_verdict = rising_arms.size * 2 > treated.size ? :mostly_rising : :keeps_rising

    def emergence_direction(compared)
      above = compared.select { |arm| arm.emergence_rate > control_for(arm).emergence_rate }
      return "Every #{treated_name} emerged at or below the #{control_name} at its own cap" if above.empty?

      pairs = above.map do |arm|
        "#{arm.label} (#{arm.emergence_fraction} against #{control_for(arm).emergence_fraction})"
      end
      clause = "#{sentence_of(pairs)} emerged more often than the #{control_name} at " \
               "#{above.one? ? 'its' : 'their'} own cap"
      return clause if above.size == compared.size

      "#{clause}, and every other #{treated_name} at or below it"
    end

    def significance(compared)
      threshold = format("p < %.2f", OpenEndednessSurvey::SIGNIFICANCE)
      significant = compared.select { |arm| emergence_significant?(arm) }
      return "none of the differences reaches #{threshold}" if significant.empty?

      "the difference at #{sentence_of(significant.map(&:label))} " \
        "#{verb_for(significant.size, %w[reaches reach])} #{threshold}"
    end

    def barren_sentence
      barren = treated.select(&:barren?)
      return "" if barren.empty?

      verb = verb_for(barren.size, ["emerged in none of its runs and reads", "emerged in none of their runs and read"])

      " #{sentence_of(barren.map { |arm| "#{arm.label} (#{arm.emergence_fraction})" })} #{verb} " \
        "barren: #{barren.one? ? 'an arm' : 'arms'} holding no replicator to read."
    end

    def theft_null_sentence = [never_evolved_sentence, theft_unmeasured_sentence].compact.join(" ")

    def never_evolved_sentence
      never = steal_arms.select { |arm| arm.theft == :never_evolved }
      if never.empty?
        return "So no steal arm reads the theft-never-evolved null, which would have said nothing about " \
               "whether theft helps."
      end

      "#{sentence_of(never.map(&:label))} #{verb_for(never.size, %w[reads read])} theft never evolved: " \
        "the op was there and no lineage used it, which says nothing about whether theft helps."
    end

    def theft_unmeasured_sentence
      unmeasured = steal_arms.select { |arm| arm.theft == :unmeasured }
      return nil if unmeasured.empty?

      "#{sentence_of(unmeasured.map(&:label))} carried no steal_rate sample and " \
        "#{verb_for(unmeasured.size, %w[reads read])} unmeasured."
    end

    def pre_registered_measured_count(arm) = arm.measured_count - arm.pre_registered_unmeasured_count

    def format_p(value) = format("%.2g", value)

    def theft_share(count, total)
      return "#{count.zero? ? 'did not evolve' : 'evolved'} in the one steal arm" if total == 1
      return "evolved in none of the #{total} steal arms" if count.zero?
      return "evolved in every one of the #{total} steal arms" if count == total

      "evolved in #{count} of the #{total} steal arms"
    end

    def range_of(values)
      low, high = values.minmax.map { |value| format("%.2f", value) }
      low == high ? low : "#{low}–#{high}"
    end
  end
end
