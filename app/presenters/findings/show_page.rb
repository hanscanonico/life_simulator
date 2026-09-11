# frozen_string_literal: true

module Findings
  # One finding: its narrative, then the live evidence — the same phase diagrams and the
  # same runs the experiment page draws, from the same presenter.
  class ShowPage
    MAX_TRANSITIONS = 50

    # One finished run that crossed the transition detector or counted a replicator, with
    # the extrema that say which of the two happened.
    Transition = Data.define(:run, :arm_label, :transition_epoch, :peak_replicator_count, :peak_epoch,
                             :min_entropy_bits, :max_copy_rate)

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

    def runs_done = evidence ? evidence.finished_count : 0

    def pending? = runs_done.zero?

    # The rows behind the claim. The detector and the census disagree on which runs are
    # interesting, so a run qualifies on either, and the page shows both observables
    # rather than choosing between them.
    def transitions = @transitions ||= transition_rows.first(MAX_TRANSITIONS)

    def transitions_capped? = transition_rows.size > MAX_TRANSITIONS

    def arm_column = arm_axis ? arm_axis.name.to_s.humanize : "Arm"

    private

    def transition_rows = @transition_rows ||= candidate_runs.filter_map { |run| transition_for(run) }

    def transition_for(run)
      samples = run.samples.order(:epoch).pluck(:epoch, :values)
      peak_epoch, peak = peak_replicators(samples)
      return nil if run.transition_epoch.nil? && !peak.to_f.positive?

      Transition.new(run: run, arm_label: arm_axis&.label_of_run(run.params),
                     transition_epoch: run.transition_epoch, peak_replicator_count: peak,
                     peak_epoch: peak_epoch, min_entropy_bits: observable(samples, "entropy_bits").min,
                     max_copy_rate: observable(samples, "copy_rate").max)
    end

    # Ties go to the earliest epoch: the peak is reported as the first time the census
    # reached it.
    def peak_replicators(samples)
      counted = samples.filter_map do |epoch, values|
        count = numeric(values["replicator_count"])
        [epoch, count] if count
      end

      counted.max_by { |epoch, count| [count, -epoch] } || [nil, nil]
    end

    def observable(samples, name) = samples.filter_map { |_epoch, values| numeric(values[name]) }

    def numeric(value) = value.is_a?(Numeric) ? value.to_f : nil

    def candidate_runs
      return [] unless experiment?

      finished_runs.where(id: candidate_ids).order(:transition_epoch, :id).limit(MAX_TRANSITIONS + 1).to_a
    end

    def candidate_ids = finished_runs.where.not(transition_epoch: nil).ids | counted_run_ids

    # `runs.summary` carries the newest sample, not a peak, so the census needs the
    # samples. One grouped scan over the sweep's finished runs names the candidates and the
    # extrema above then read the samples of those runs alone. Numbers sort above strings
    # in jsonb, so a non-numeric count never passes the comparison.
    def counted_run_ids
      Sample.where(run_id: finished_runs.select(:id))
            .where("values -> 'replicator_count' > '0'::jsonb")
            .distinct.pluck(:run_id)
    end

    def finished_runs = experiment.runs.where(status: "finished")

    def arm_axis = evidence&.axes&.first
  end
end
