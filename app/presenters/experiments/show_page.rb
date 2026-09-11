# frozen_string_literal: true

module Experiments
  # One sweep: a phase diagram per swept parameter, then the runs behind it.
  class ShowPage
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

    def transition_report? = finished_count.positive? && transition_arms.any?

    def transition_threshold = TransitionReportService::THRESHOLD

    def transition_rate = TransitionRate.new(transitioned: transitioned_finished, finished: finished_count)

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

      Charts::Survival::Observation.new(epochs: epochs.to_i, event: run.transition_epoch.present?)
    end

    def observed_epochs(run)
      return run.epochs_done if run.terminal?

      [run.epochs_done, latest_sample_epochs[run.id].to_i].max
    end

    def observed_runs
      @observed_runs ||= experiment.runs.where.not(status: "pending")
                                   .select(:id, :params, :status, :epochs_done, :transition_epoch).to_a
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
