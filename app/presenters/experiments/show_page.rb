# frozen_string_literal: true

module Experiments
  # One sweep: a phase diagram per swept parameter, then the runs behind it.
  class ShowPage
    # What the replicator census says about one run, against what the transition detector
    # said. `transition_epoch` fires on `compress_ratio` alone (DESIGN.md §1.2), so the two
    # disagree, and every top_k or persistence decision is argued over the runs where they
    # do. A census that never left zero has no peak: that is a reading, not a gap.
    Census = Data.define(:peak, :transitioned) do
      def counted? = peak.present?

      def detector_only? = transitioned && !counted?

      def census_only? = counted? && !transitioned
    end

    def self.build(experiment:, paginate:)
      new(experiment: experiment, paginate: paginate)
    end

    def initialize(experiment:, paginate:)
      @experiment = experiment
      @paginate = paginate
    end

    attr_reader :experiment

    def axes = @axes ||= Axis.sweep(experiment.param_grid)

    def diagrams = diagrams_by_axis.values

    def diagram_for(axis) = diagrams_by_axis.fetch(axis)

    # One summary per grid value, per axis: the numbers the phase diagram draws.
    def arms = @arms ||= axes.index_with { |axis| arms_for(axis) }

    # One Kaplan–Meier curve set per axis: every run that has been watched at all, live
    # runs included, so the page answers "how long does emergence take" while a sweep runs.
    def survivals = @survivals ||= axes.index_with { |axis| survival_for(axis) }

    # One column per swept axis, headed and filled with the same label the phase diagram
    # and the arm table use, so a row of the runs table can be matched to an arm.
    def arm_columns = @arm_columns ||= axes.map { |axis| axis.name.to_s.humanize }

    def arm_labels_of(run) = axes.map { |axis| axis.label_of_run(run.params) }

    def runs = page.last

    def pagy = page.first

    # A run nothing has been sampled from yet — a pending one above all — has no census at
    # all, and the table says nothing about it rather than reading a zero into it. The
    # summary is written with the samples, so it is the sampled flag already at hand.
    def census_of(run)
      return nil unless run.summary.key?("replicator_count")

      Census.new(peak: census_peaks[run.id], transitioned: run.transition_epoch.present?)
    end

    def findings = @findings ||= Findings::Registry.for_experiment(experiment.slug)

    def finished_count = finished_runs.size

    def transitioned_finished = finished_runs.count { |run| run.transition_epoch.present? }

    # Runs still under way can already carry a transition epoch, and they are not in the
    # rate's denominator: the page reports them separately rather than diluting the share.
    def transitioned_running
      @transitioned_running ||= experiment.runs.where(status: %w[claimed running])
                                          .where.not(transition_epoch: nil).count
    end

    # The page that makes the claim shows how often the two observables disagree; the
    # per-run rows behind the counts stay in the transition report CSV.
    def transition_arms = @transition_arms ||= TransitionArmsService.call(experiment: experiment)

    # The same counts as a picture: which arms disagree, and which way.
    def agreement_chart
      @agreement_chart ||= Charts::AgreementChart.new(arms: transition_arms,
                                                      title: "Detector against replicator census, per arm")
    end

    def transition_report? = finished_count.positive? && transition_arms.any?

    def transition_threshold = TransitionReportService::THRESHOLD

    def transition_rate = TransitionRate.new(transitioned: transitioned_finished, finished: finished_count)

    # Only a sweep a corpus pass has read carries this section: without rescores there is
    # nothing to say about `top_k`.
    def rescore_summary = @rescore_summary ||= RescoreSummary.build(experiment: experiment)

    def rescores? = rescore_summary.any?

    private

    def survival_for(axis)
      arms = axis.values.map do |value|
        observations = observed_runs.select { |run| axis.matches?(run.params, value) }.map { |run| observation(run) }
        Charts::Survival::Arm.new(label: axis.label_of(value), observations: observations.compact)
      end
      Charts::Survival.new(arms: arms, title: "Time to emergence vs #{axis.name.to_s.humanize.downcase}")
    end

    # A run that emerged was watched up to its transition; one that did not is censored at
    # the last epoch it is known to have reached — the whole budget for a terminal run, the
    # latest sample for a run still under way. A run nothing is known about yet is no
    # observation at all.
    def observation(run)
      epochs = run.transition_epoch || observed_epochs(run)
      return nil unless epochs.to_i.positive?

      Charts::Survival::Observation.new(epochs: epochs.to_i, event: run.transition_epoch.present?,
                                        persistence: run.persistence_summary)
    end

    def observed_epochs(run)
      return run.epochs_done if run.terminal?

      [run.epochs_done, latest_sample_epochs[run.id].to_i].max
    end

    def observed_runs
      @observed_runs ||= experiment.runs.where.not(status: "pending")
                                   .select(:id, :params, :status, :epochs_done, :transition_epoch, :persistence).to_a
    end

    # One grouped query for the whole page, never one per row, served by
    # `index_samples_on_run_id_replicated` — whose predicate this `where` has to keep
    # matching. Numbers sort above strings in jsonb, so a non-numeric count never passes
    # the comparison.
    def census_peaks
      @census_peaks ||= Sample.where(run_id: runs.map(&:id))
                              .where("values -> 'replicator_count' > '0'::jsonb")
                              .group(:run_id)
                              .maximum(Arel.sql("(values ->> 'replicator_count')::numeric"))
    end

    def latest_sample_epochs
      @latest_sample_epochs ||= Sample.where(run_id: observed_runs.reject(&:terminal?).map(&:id))
                                      .group(:run_id).maximum(:epoch)
    end

    def diagrams_by_axis
      @diagrams_by_axis ||= axes.index_with do |axis|
        Charts::PhaseDiagram.new(groups: groups_for(axis), title: axis.title, x_label: axis.name.to_s.humanize,
                                 epochs: experiment.epochs, log_x: axis.log?)
      end
    end

    def arms_for(axis)
      axis.values.map do |value|
        runs = finished_runs.select { |run| axis.matches?(run.params, value) }
        epochs, censored = runs.partition { |run| run.transition_epoch.present? }
        ArmSummary.new(label: axis.label_of(value), transition_epochs: epochs.map(&:transition_epoch),
                       censored: censored.size)
      end
    end

    def page = @page ||= @paginate.call(experiment.runs.order(:id))

    def finished_runs
      @finished_runs ||= experiment.runs.where(status: "finished").select(:id, :params, :transition_epoch).to_a
    end

    def groups_for(axis)
      axis.values.zip(arms[axis]).map do |value, arm|
        Charts::PhaseDiagram::Group.new(value: axis.position_of(value), label: arm.label,
                                        transition_epochs: arm.transition_epochs, censored: arm.censored)
      end
    end
  end
end
