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

    def axes
      @axes ||= experiment.param_grid.filter_map do |name, values|
        Axis.new(name: name, values: values) if values.is_a?(Array) && values.size > 1
      end
    end

    def diagrams = diagrams_by_axis.values

    def diagram_for(axis) = diagrams_by_axis.fetch(axis)

    # One summary per grid value, per axis: the numbers the phase diagram draws.
    def arms = @arms ||= axes.index_with { |axis| arms_for(axis) }

    def varying_keys = @varying_keys ||= axes.flat_map(&:param_keys).uniq

    def runs = page.last

    def pagy = page.first

    def runs_done = finished_runs.size

    def transitioned = finished_runs.count { |run| run.transition_epoch.present? }

    def transition_rate
      return nil if runs_done.zero?

      transitioned.fdiv(runs_done)
    end

    private

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
