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

    # Headed and labelled by the experiment's own presenter, so a row of this table can be
    # matched to an arm of the phase diagram and the runs table below it.
    def arm_column = evidence&.arm_columns&.first || "Arm"

    private

    def transition_rows = @transition_rows ||= rows_of(candidate_runs)

    # The samples of every candidate are read in one query and handed to the rows, so the
    # table costs the same two queries at one row as it does at the cap.
    def rows_of(runs)
      samples = samples_by_run(runs)

      runs.filter_map { |run| transition_for(run, samples.fetch(run.id, [])) }
    end

    def samples_by_run(runs)
      return {} if runs.empty?

      Sample.where(run_id: runs.map(&:id)).order(:epoch).pluck(:run_id, :epoch, :values)
            .group_by(&:first)
            .transform_values { |rows| rows.map { |(_, epoch, values)| [epoch, values] } }
    end

    def transition_for(run, samples)
      peak_epoch, peak = peak_replicators(samples)
      return nil if run.transition_epoch.nil? && !peak.to_f.positive?

      Transition.new(run: run, arm_label: evidence&.arm_labels_of(run)&.first,
                     transition_epoch: run.transition_epoch, peak_replicator_count: peak,
                     peak_epoch: peak_epoch, min_entropy_bits: observable(samples, "entropy_bits").min,
                     max_copy_rate: observable(samples, "copy_rate").max)
    end

    # Ties go to the earliest epoch: the peak is reported as the first time the census
    # reached it. A census that never left zero peaked nowhere, so it reports no epoch.
    def peak_replicators(samples)
      counted = samples.filter_map do |epoch, values|
        count = numeric(values["replicator_count"])
        [epoch, count] if count
      end
      epoch, peak = counted.max_by { |sample_epoch, count| [count, -sample_epoch] }
      return [nil, nil] if peak.nil?

      [peak.positive? ? epoch : nil, peak]
    end

    def observable(samples, name) = samples.filter_map { |_epoch, values| numeric(values[name]) }

    def numeric(value) = value.is_a?(Numeric) ? value.to_f : nil

    def candidate_runs
      return [] unless experiment?

      finished_runs.where.not(transition_epoch: nil)
                   .or(finished_runs.where(id: counted_run_ids))
                   .order(:transition_epoch, :id).limit(MAX_TRANSITIONS + 1).to_a
    end

    # `runs.summary` carries the newest sample, not a peak, so the census needs the
    # samples. The candidates are named by a subquery rather than a second round trip, and
    # it is served by `index_samples_on_run_id_replicated` — whose predicate this `where`
    # has to keep matching. Numbers sort above strings in jsonb, so a non-numeric count
    # never passes the comparison.
    def counted_run_ids
      Sample.where("values -> 'replicator_count' > '0'::jsonb").select(:run_id)
    end

    def finished_runs = experiment.runs.where(status: "finished")
  end
end
