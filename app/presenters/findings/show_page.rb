# frozen_string_literal: true

module Findings
  # One finding: its narrative, then the live evidence — the same phase diagrams and the
  # same runs the experiment page draws, from the same presenter.
  class ShowPage
    def self.build(finding:, paginate:)
      new(finding: finding, paginate: paginate)
    end

    def initialize(finding:, paginate:)
      @finding = finding
      @paginate = paginate
    end

    attr_reader :finding

    def experiment
      return @experiment if defined?(@experiment)

      @experiment = Experiment.find_by(slug: finding.experiment_slug)
    end

    def experiment? = experiment.present?

    # The evidence is read through the experiment's own presenter: a finding never
    # re-derives a diagram of its own.
    def evidence
      return nil unless experiment?

      @evidence ||= Experiments::ShowPage.build(experiment: experiment, paginate: @paginate)
    end

    def diagrams = evidence ? evidence.diagrams : []

    def runs_done = evidence ? evidence.runs_done : 0

    def pending? = runs_done.zero?
  end
end
