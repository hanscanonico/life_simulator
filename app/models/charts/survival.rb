# frozen_string_literal: true

module Charts
  # Time to emergence, read as a survival curve: S(t) is the probability that a run has
  # *not* produced a self-replicator by epoch t.
  #
  # A sweep is heavily censored — most runs reach the end of their epoch budget with
  # nothing having emerged, and a run still under way has only been watched up to its
  # latest sample — so a count of transitions, or a median over the runs that did
  # transition, answers a different question than DESIGN.md's. The Kaplan–Meier estimator
  # below keeps a censored run in the denominator for as long as it was actually watched
  # and drops it afterwards, which is what makes the curve comparable across arms that ran
  # for different lengths.
  class Survival
    include Plot

    # One solid line, then dash patterns that stay apart at chart scale and in print. The
    # widest sweep of DESIGN §1.3 (mutation rate) has ten arms, so there are ten patterns.
    DASHES = ["none", "7 4", "2 3", "11 4 2 4", "16 5", "4 2 1 2", "1 5", "9 4 4 4", "3 7",
              "14 4 1 4 1 4"].freeze
    HAZARD_UNIT = 10_000

    # One run: `epochs` is the transition epoch when it emerged, and otherwise how long
    # the run was watched without an emergence. `persistence` is what became of the world
    # after that emergence (Runs::Persistence), absent for a censored run and for an
    # emergence nothing has summarised yet.
    Observation = Data.define(:epochs, :event, :persistence) do
      def initialize(epochs:, event:, persistence: nil) = super
    end

    Step = Data.define(:epoch, :survival, :at_risk, :events)

    Line = Data.define(:label, :dash, :path)

    # Every run at one grid value (or, pooled, at all of them).
    class Arm
      def initialize(label:, observations:)
        @label = label
        @observations = observations.sort_by(&:epochs)
      end

      attr_reader :label, :observations

      def runs = observations.size

      def events = observations.count(&:event)

      # The run-epochs at risk: every epoch a run spent under observation without having
      # emerged yet, which is exactly the denominator of the hazard.
      def exposure = observations.sum(&:epochs)

      # Of the emergences this arm has a persistence summary for, how many the world was
      # still in at its last sample and how many it climbed back out of. An arm whose
      # emergences have not been summarised has neither count rather than two zeroes.
      def summarised = persistences.size

      def persisted = persistences.count { |persistence| !persistence.relapsed? }

      def relapsed = persistences.count(&:relapsed?)

      def hazard = @hazard ||= PoissonRate.new(events: events, exposure: exposure)

      def hazard_per_unit = hazard.per(HAZARD_UNIT)

      def last_epoch = observations.last&.epochs || 0

      # The step function: one step down per epoch at which an emergence happened, the
      # drop weighted by how many runs were still at risk there. A run censored at epoch t
      # is at risk through t and gone after it, so it flattens later steps instead of
      # counting as an emergence (ignoring censoring) or vanishing from the denominator
      # from the start (dropping it).
      def steps
        @steps ||= begin
          survival = 1.0
          event_epochs.map do |epoch|
            at_risk = observations.count { |observation| observation.epochs >= epoch }
            here = observations.count { |observation| observation.event && observation.epochs == epoch }
            survival *= 1 - here.fdiv(at_risk)
            Step.new(epoch: epoch, survival: survival, at_risk: at_risk, events: here)
          end
        end
      end

      # S(t) for any epoch, the curve being constant between steps.
      def survival_at(epoch)
        steps.take_while { |step| step.epoch <= epoch }.last&.survival || 1.0
      end

      private

      def persistences = @persistences ||= observations.filter_map(&:persistence)

      def event_epochs = observations.select(&:event).map(&:epochs).uniq.sort
    end

    def initialize(arms:, title:)
      @arms = arms
      @title = title
    end

    attr_reader :arms, :title

    def to_partial_path = "charts/survival"

    def x_label = "Epoch"

    def y_label = "P(no emergence)"

    def empty? = arms.all? { |arm| arm.runs.zero? }

    # One row under the chart: the whole sweep, censoring and all.
    def pooled = @pooled ||= Arm.new(label: "All arms", observations: arms.flat_map(&:observations))

    def lines
      arms.reject { |arm| arm.runs.zero? }.map.with_index do |arm, index|
        Line.new(label: legend_label(arm), dash: DASHES[index % DASHES.size], path: path_for(arm))
      end
    end

    def x_scale = @x_scale ||= Scale.new(values: [0.0, horizon], length: plot_width)

    def y_scale = @y_scale ||= Scale.new(values: [0.0, 1.0], length: plot_height, flip: true)

    private

    def legend_label(arm)
      "#{arm.label} — #{arm.events} of #{arm.runs} emerged"
    end

    # The curve is drawn out to the longest run anywhere in the sweep, so the arms share
    # one x axis; a budget that nothing has reached yet would leave dead space.
    def horizon = @horizon ||= [arms.map(&:last_epoch).max.to_f, 1.0].max

    def path_for(arm)
      points = [[0.0, 1.0]]
      arm.steps.each do |step|
        points << [step.epoch.to_f, points.last.last] << [step.epoch.to_f, step.survival]
      end
      points << [horizon, points.last.last]
      draw(points.uniq)
    end

    def draw(points)
      points.map.with_index do |(x, y), index|
        "#{index.zero? ? 'M' : 'L'}#{x_pixel(x).round(2)},#{y_pixel(y).round(2)}"
      end.join(" ")
    end
  end
end
