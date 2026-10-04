# frozen_string_literal: true

module Findings
  # One published claim: a sweep written up against its own runs (DESIGN.md §1.3). A
  # finding is content in the repo, not a database row, so it is versioned with the
  # narrative it introduces and never drifts from the data it points at.
  #
  # `imports_objective` is the Metabolism label (DESIGN.md §1.4): a finding read from runs
  # paid for computing carries the "imports an objective" badge wherever its status does. It
  # is stated in the entry rather than derived from the runs, so the index reads no run for
  # it, and the registry spec holds every finding on a Metabolism sweep to it.
  # `imports_machine` is the out-compute label, by the same rule: a finding read from runs
  # whose energy moves by what their tapes compute carries the "imports a machine, not an
  # objective" badge, and the registry spec holds every finding on the out-compute sweep to it.
  class Finding < Data.define(:slug, :title, :date, :experiment_slug, :status, :summary, :body_partial,
                              :related_experiment_slugs, :related_finding_slugs, :imports_objective,
                              :imports_machine)
    STATUSES = %i[open partial published negative].freeze

    BADGE_CLASSES = {
      open: "badge-info",
      partial: "badge-warning",
      published: "badge-success",
      negative: "badge-error"
    }.freeze

    STATUS_MEANINGS = {
      open: "The sweep is running and no claim is made yet.",
      partial: "A reading is stated, but it cannot yet be read as final.",
      published: "Every run finished and the claim stands on them.",
      negative: "The sweep finished and the effect was not there."
    }.freeze

    OBJECTIVE_MEANING = "Read from Metabolism, a second substrate that pays a cell for computing: " \
                        "it imports an objective and is never pooled with the fitness-free runs. " \
                        "Rung 4 on Soup is unaffected by it."

    MACHINE_MEANING = "Read from runs under predation, an interaction rule that moves energy by what the " \
                      "tapes compute and names no computation, or carrying a priced, heritable fidelity: it " \
                      "imports a machine to compute with, not an objective, and is never pooled with the " \
                      "fitness-free runs. Rung 4 on Soup is unaffected by it."

    # Neither label unless the entry states it.
    LABELS = { imports_objective: false, imports_machine: false }.freeze

    # ERB partial names must be valid Ruby identifiers, so a slug's hyphens become
    # underscores on the way to the file name.
    def initialize(slug:, title:, date:, experiment_slug:, status:, summary:, body_partial: nil,
                   related_experiment_slugs: [], related_finding_slugs: [], **labels)
      raise ArgumentError, "unknown finding status #{status.inspect}" unless STATUSES.include?(status)

      super(slug: slug, title: title, date: date, experiment_slug: experiment_slug, status: status,
            summary: summary, body_partial: body_partial || "findings/bodies/#{slug.tr('-', '_')}",
            related_experiment_slugs: related_experiment_slugs.freeze,
            related_finding_slugs: related_finding_slugs.freeze, **LABELS.merge(labels))
    end

    def to_param = slug

    # A finding usually writes up one sweep, but one can rest on every run the lab has
    # instead, in which case it names no sweep and carries its own evidence.
    def sweep? = experiment_slug.present?

    # A finding can also weigh several sweeps against each other, in which case it names
    # them here: it is written up from all of them, so each of their pages lists it, and
    # none of them alone is the sweep it rests on.
    def experiment_slugs = [experiment_slug, *related_experiment_slugs].compact

    def rests_on?(slug) = experiment_slugs.include?(slug)

    def badge_class = BADGE_CLASSES.fetch(status)

    def status_label = status.to_s

    def status_meaning = STATUS_MEANINGS.fetch(status)

    def imports_objective? = imports_objective

    def imports_machine? = imports_machine

    def instrument_note = InstrumentNotes.for(slug)

    def instrument_note? = instrument_note.present?
  end
end
