# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charts::Survival do
  subject(:survival) { described_class.new(arms: [arm], title: "Time to emergence") }

  def observations(*pairs)
    pairs.map { |epochs, event| Charts::Survival::Observation.new(epochs: epochs, event: event) }
  end

  # Five runs: emergences at 2, 4 and 7, censored at 3 and 6. By hand, Kaplan-Meier walks
  # the event epochs only, with the censored runs still in the denominator up to their own
  # epoch: S(2) = 1 - 1/5 = 0.8, S(4) = 0.8 * (1 - 1/3), S(7) = 0.5333 * (1 - 1/1) = 0.
  let(:arm) do
    Charts::Survival::Arm.new(label: "1", observations: observations([2, true], [3, false], [4, true],
                                                                     [6, false], [7, true]))
  end

  describe Charts::Survival::Arm do
    describe "#steps" do
      it "steps down once per epoch at which something emerged" do
        expect(arm.steps.map(&:epoch)).to eq([2, 4, 7])
      end

      it "weights each drop by the runs still at risk, censored ones included" do
        expect(arm.steps.map(&:at_risk)).to eq([5, 3, 1])
        expect(arm.steps.map(&:survival)).to all(be_a(Float))
        expect(arm.steps.map { |step| step.survival.round(6) }).to eq([0.8, 0.533333, 0.0])
      end

      context "with two emergences at the same epoch" do
        let(:arm) do
          Charts::Survival::Arm.new(label: "1", observations: observations([5, true], [5, true], [9, false]))
        end

        it "drops once, by both events" do
          expect(arm.steps.map { |step| [step.epoch, step.events, step.at_risk, step.survival.round(6)] })
            .to eq([[5, 2, 3, 0.333333]])
        end
      end

      context "with nothing but censored runs" do
        let(:arm) { Charts::Survival::Arm.new(label: "1", observations: observations([4, false], [9, false])) }

        it "never steps down" do
          expect(arm.steps).to be_empty
          expect(arm.survival_at(9)).to eq(1.0)
        end
      end

      context "with the last run censored after the last emergence" do
        let(:arm) do
          Charts::Survival::Arm.new(label: "1", observations: observations([2, true], [8, false], [9, false]))
        end

        it "keeps the curve above zero: two runs ended with no emergence" do
          expect(arm.steps.map { |step| step.survival.round(6) }).to eq([0.666667])
          expect(arm.survival_at(9)).to be_within(1e-9).of(2 / 3.0)
        end
      end
    end

    describe "#survival_at" do
      it "is flat between the steps" do
        expect(arm.survival_at(0)).to eq(1.0)
        expect(arm.survival_at(3)).to be_within(1e-9).of(0.8)
        expect(arm.survival_at(6)).to be_within(1e-9).of(0.8 * 2 / 3)
      end
    end

    describe "#persisted_count" do
      def persistence(relapsed) = Runs::Persistence.new(census_peak: 3, peak_epoch: 1, epochs_persisted: 2, relapsed: relapsed)

      let(:arm) do
        Charts::Survival::Arm.new(
          label: "1",
          observations: [Charts::Survival::Observation.new(epochs: 2, event: true, persistence: persistence(false)),
                         Charts::Survival::Observation.new(epochs: 3, event: true, persistence: persistence(false)),
                         Charts::Survival::Observation.new(epochs: 4, event: true, persistence: persistence(true)),
                         Charts::Survival::Observation.new(epochs: 5, event: true),
                         Charts::Survival::Observation.new(epochs: 6, event: false)]
        )
      end

      it "counts the emergences the world stayed in against the ones it left" do
        expect(arm).to have_attributes(summarised_count: 3, persisted_count: 2, relapsed_count: 1)
      end

      context "with an arm nothing has summarised" do
        it "counts nothing rather than a row of zeroes" do
          expect(Charts::Survival::Arm.new(label: "1", observations: observations([2, true])).summarised_count).to eq(0)
        end
      end
    end

    describe "#exposure" do
      it "sums the epochs every run spent at risk, whether or not it emerged" do
        expect(arm.exposure).to eq(22)
      end
    end

    describe "#hazard" do
      it "is the events over the run-epochs at risk, with an exact interval" do
        interval = arm.hazard_per_unit

        expect(arm.events).to eq(3)
        expect(interval.value).to be_within(1e-6).of(1363.636364)
        expect(interval.lower).to be_within(1e-1).of(281.2)
        expect(interval.upper).to be_within(1e-1).of(3985.1)
      end

      context "with no run" do
        it "reports no hazard rather than a hazard of zero" do
          empty = Charts::Survival::Arm.new(label: "1", observations: [])

          expect(empty.hazard_per_unit.value).to be_nil
        end
      end
    end
  end

  describe "#lines" do
    subject(:survival) do
      described_class.new(arms: [arm, other, Charts::Survival::Arm.new(label: "4", observations: [])],
                          title: "Time to emergence")
    end

    let(:other) { Charts::Survival::Arm.new(label: "2", observations: observations([6, true], [9, false])) }

    it "draws one line per arm that has runs, each with its own dash pattern" do
      expect(survival.lines.map(&:label)).to eq(["1 — 3 of 5 emerged", "2 — 1 of 2 emerged"])
      expect(survival.lines.map(&:dash).uniq.size).to eq(2)
    end

    it "starts every line at S = 1 on the left edge and holds it to the shared horizon" do
      path = survival.lines.first.path

      expect(path).to start_with("M#{survival.plot_left.to_f.round(2)},#{survival.plot_top.to_f.round(2)}")
      expect(path).to end_with("L#{survival.x_pixel(9.0).round(2)},#{survival.y_pixel(0.0).round(2)}")
    end

    it "shares one x axis across the arms, out to the longest run anywhere in the sweep" do
      expect(survival.lines.last.path).to end_with("L#{survival.x_pixel(9.0).round(2)}," \
                                                   "#{survival.y_pixel(0.5).round(2)}")
    end
  end

  describe "#pooled" do
    subject(:survival) { described_class.new(arms: [arm, other], title: "Time to emergence") }

    let(:other) { Charts::Survival::Arm.new(label: "2", observations: observations([6, true], [9, false])) }

    it "is every run of the sweep in one arm" do
      expect(survival.pooled).to have_attributes(label: "All arms", runs: 7, events: 4, exposure: 37)
    end
  end

  describe "#empty?" do
    it "has something to draw" do
      expect(survival).not_to be_empty
    end

    context "with no arm that has been observed" do
      it "is empty" do
        blank = described_class.new(arms: [Charts::Survival::Arm.new(label: "1", observations: [])],
                                    title: "Time to emergence")

        expect(blank).to be_empty
      end
    end
  end
end
