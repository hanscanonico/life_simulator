# frozen_string_literal: true

module Findings
  # The sentences a finding states its claim in, composed from a ComplexityArmsReading's
  # arms: the headline, what each rising arm stands on, and the refutation condition checked
  # against what the controls actually read. Nothing here names a sweep; the reading's two
  # nouns do.
  class ComplexityArmsHeadline
    include ArmsProse

    # The arm readings in the order a headline lists them, each as the verb it takes after
    # one arm and after several.
    VERBS = {
      keeps_rising: ["keeps rising", "keep rising"],
      mixed: ["reads mixed", "read mixed"],
      plateau: %w[plateaus plateau],
      neither: ["reads neither", "read neither"],
      unread: ["has too few measured runs to read", "have too few measured runs to read"],
      barren: ["held no replicator at all", "held no replicator at all"]
    }.freeze

    def initialize(reading:)
      @reading = reading
    end

    def headline
      return "No #{treated_name} has a run to read yet." if treated.empty?

      "#{lead}#{rest_clause}, #{control_clause}."
    end

    # What a rising arm stands on: its own measured runs, and how its control at the same
    # cap reads run by run, so one arm is never read without the arm it is set against.
    def rising_notes = rising_arms.map { |arm| rising_note(arm) }

    def refutation_sentence
      if controls.empty?
        return "No #{control_name} has been read yet, so the condition cannot be checked against these runs."
      end

      "Checked against the condition as worded: #{control_readings}. #{refutation_outcome}"
    end

    def refutation_met? = plateau_controls.any? && plateau_controls.size == controls.size && unmatched_arms.empty?

    private

    attr_reader :reading

    delegate :treated, :controls, :rising_arms, :control_for, :treated_name, :control_name, to: :reading

    def lead
      rising = rising_arms
      return "Complexity #{rising.empty? ? 'did not keep' : 'kept'} rising in the one #{treated_name}" if treated.one?
      return "Complexity kept rising in none of the #{counted(treated.size, treated_name)}" if rising.empty?

      details = rising.map { |arm| "#{arm.label}, on #{arm.rising_count} of its #{arm.measured_count} measured runs" }
      "Complexity kept rising in #{rising.size} of the #{counted(treated.size, treated_name)} — " \
        "#{sentence_of(details)}"
    end

    def rest_clause
      clauses = (VERBS.keys - [:keeps_rising]).filter_map do |reading|
        count = treated.count { |arm| arm.reading == reading }
        next if count.zero?

        "#{treated.one? ? 'it' : count} #{verb_for(count, VERBS.fetch(reading))}"
      end
      return "" if clauses.empty?

      "#{rising_arms.empty? ? ':' : ';'} #{sentence_of(clauses)}"
    end

    def control_clause
      return "and there is no #{control_name} to read them against" if controls.empty?
      return "while the #{control_name} #{verb_for(1, VERBS.fetch(controls.first.reading))}" if controls.one?

      readings = controls.map(&:reading).uniq
      if readings.one?
        "while #{controls.size == 2 ? 'both' : "all #{controls.size}"} #{control_name.pluralize} " \
          "#{verb_for(controls.size, VERBS.fetch(readings.first))}"
      else
        "while the #{control_name.pluralize} part: #{control_readings}"
      end
    end

    def control_readings
      sentence_of(controls.map { |arm| "#{arm.label} #{verb_for(1, VERBS.fetch(arm.reading))}" })
    end

    def rising_note(arm)
      paired = control_for(arm)
      fewest = arm.measured_count == ComplexityArmsReading::MIN_ARM_RUNS
      smallest = fewest ? ", the fewest the rule reads an arm on" : ""
      note = "#{arm.label} reads on #{counted(arm.measured_count, 'measured run')}#{smallest}"
      return "#{note}, and has no #{control_name} at its cap." if paired.nil?

      "#{note}; its #{control_name}, #{paired.label}, has #{paired.rising_count} rising of " \
        "#{counted(paired.measured_count, 'measured run')} and reads #{paired.reading.to_s.tr('_', ' ')}."
    end

    def plateau_controls = controls.select { |arm| arm.reading == :plateau }

    # The treated arms beside a plateaued control that neither plateau nor hold a
    # replicator: the arms that keep the refutation condition from being met.
    def unmatched_arms
      caps = plateau_controls.map(&:cap)

      treated.select { |arm| caps.include?(arm.cap) && %i[plateau barren].exclude?(arm.reading) }
    end

    def refutation_outcome
      if plateau_controls.empty?
        return "no #{control_name} plateaus, so there is no control plateau for a #{treated_name} to match " \
               "and the condition is not met on these runs.".upcase_first
      end
      if unmatched_arms.any?
        return "The condition is not met: #{sentence_of(unmatched_arms.map(&:label))} " \
               "#{verb_for(unmatched_arms.size, %w[does do])} not plateau where " \
               "#{unmatched_arms.one? ? 'its' : 'their'} control does."
      end
      if refutation_met?
        return "Every #{treated_name} plateaus or holds no replicator where its control plateaus, " \
               "so the condition is met."
      end

      "Where a #{control_name} plateaus, every #{treated_name} beside it plateaus or holds no replicator, " \
        "but not every #{control_name} plateaus, so the condition is met at some caps only."
    end
  end
end
