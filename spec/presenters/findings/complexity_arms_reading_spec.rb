# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::ComplexityArmsReading do
  subject(:reading) do
    described_class.build(experiment: experiment, complexity_arms: complexity_arms,
                          control: ->(params) { params["energy_influx"].to_i.zero? },
                          treated_name: "priced arm", control_name: "economy-off control")
  end

  let(:off) { { "energy_influx" => 0, "steal_amount" => 0 } }
  let(:priced) { { "energy_influx" => 512, "steal_amount" => 0 } }
  let(:steal) { { "energy_influx" => 512, "steal_amount" => 1_024 } }
  let(:experiment) do
    create(:experiment, param_grid: { "economy" => [off, priced, steal], "max_tape_len" => [128, 256] })
  end
  let(:complexity_arms) { [] }

  describe "#headline" do
    context "with one priced arm rising" do
      let(:complexity_arms) do
        [arm(off, 128, runs: %i[rising neither neither]),
         arm(steal, 128, runs: %i[rising neither]),
         arm(priced, 128, runs: %i[plateau plateau]),
         arm(priced, 256, runs: [])]
      end

      it "names the arm and the runs it rises on" do
        expect(reading.headline).to eq(
          "Complexity kept rising in 1 of the 3 priced arms — 1024×512 128, on 1 of its 2 measured runs; " \
          "1 plateaus and 1 held no replicator at all, while the economy-off control reads neither."
        )
      end

      it "sets the rising arm beside its own control" do
        expect(reading.rising_notes).to eq(
          ["1024×512 128 reads on 2 measured runs, the fewest the rule reads an arm on; its economy-off " \
           "control, 0 128, has 1 rising of 3 measured runs and reads neither."]
        )
      end

      it "reads a single rising arm among several as keeping rising in part" do
        expect(reading).to have_attributes(verdict: :keeps_rising, verdict_label: "keeps rising in 1 of 3 arms",
                                           badge_class: "badge-warning")
      end
    end

    context "with no priced arm rising" do
      let(:complexity_arms) do
        [arm(off, 128, runs: %i[plateau plateau]),
         arm(priced, 128, runs: %i[plateau neither]),
         arm(steal, 128, runs: [])]
      end

      it "says none rose and lists what the arms read instead" do
        expect(reading.headline).to eq(
          "Complexity kept rising in none of the 2 priced arms: 1 plateaus and 1 held no replicator at all, " \
          "while the economy-off control plateaus."
        )
      end
    end

    context "with more than one priced arm rising" do
      let(:complexity_arms) do
        [arm(off, 128, runs: %i[neither neither]), arm(off, 256, runs: %i[neither neither]),
         arm(priced, 128, runs: %i[rising rising]), arm(steal, 128, runs: %i[rising rising neither])]
      end

      it "names every rising arm and agrees the verbs for both controls" do
        expect(reading.headline).to eq(
          "Complexity kept rising in 2 of the 2 priced arms — 0×512 128, on 2 of its 2 measured runs and " \
          "1024×512 128, on 2 of its 3 measured runs, while both economy-off controls read neither."
        )
        expect(reading.verdict).to eq(:mostly_rising)
      end
    end

    context "with a rising run against a plateauing one in the same arm" do
      let(:complexity_arms) do
        [arm(off, 128, runs: %i[neither neither]), arm(priced, 128, runs: %i[rising plateau])]
      end

      it "reads the arm as mixed rather than rising" do
        expect(reading.headline).to eq(
          "Complexity did not keep rising in the one priced arm: it reads mixed, " \
          "while the economy-off control reads neither."
        )
      end
    end

    context "with barren controls" do
      let(:complexity_arms) do
        [arm(off, 128, runs: []), arm(off, 256, runs: []), arm(priced, 128, runs: %i[plateau plateau])]
      end

      it "says the controls held no replicator" do
        expect(reading.headline).to end_with("while both economy-off controls held no replicator at all.")
      end
    end

    context "with controls reading differently" do
      let(:complexity_arms) do
        [arm(off, 128, runs: []), arm(off, 256, runs: %i[plateau plateau]), arm(priced, 128, runs: %i[neither neither])]
      end

      it "names each control's reading" do
        expect(reading.headline).to end_with(
          "while the economy-off controls part: 0 128 held no replicator at all and 0 256 plateaus."
        )
      end
    end

    context "with an arm the complexity reading carries no row for" do
      let(:complexity_arms) { [arm(off, 128, runs: %i[neither neither])] }

      before { seed_runs(priced, 128, terminal: 3, emerged: 1) }

      it "reads that arm as unread" do
        expect(reading.headline).to start_with(
          "Complexity did not keep rising in the one priced arm: it has too few measured runs to read"
        )
        expect(reading.verdict).to eq(:unresolved)
      end
    end

    context "with no run of a priced arm" do
      let(:complexity_arms) { [arm(off, 128, runs: %i[neither neither])] }

      it "has nothing to state" do
        expect(reading).to have_attributes(headline: "No priced arm has a run to read yet.", verdict: :pending)
      end
    end
  end

  describe "emergence against the control at the same cap" do
    let(:complexity_arms) do
      [arm(off, 128, runs: %i[neither neither neither neither neither], terminal: 20),
       arm(off, 256, runs: %i[neither], terminal: 20),
       arm(priced, 128, runs: [], terminal: 20),
       arm(priced, 256, runs: %i[neither neither neither], terminal: 20)]
    end

    it "pairs each priced arm with the control carrying its cap" do
      expect(reading.control_for(arm_named("0×512 256")).label).to eq("0 256")
      expect(reading.control_for(arm_named("0×512 128")).label).to eq("0 128")
    end

    it "tests an arm's emerged runs against its own control's" do
      expected = Stats::FisherExact.two_sided([[3, 17], [1, 19]])

      expect(reading.emergence_p_value(arm_named("0×512 256"))).to eq(expected)
      expect(reading.emergence_p_value(arm_named("0 256"))).to be_nil
    end

    it "names the arm above its control and the barren one" do
      expect(reading.emergence_sentence).to eq(
        "0×512 256 (3 of 20 against 1 of 20) emerged more often than the economy-off control at its own cap, " \
        "and every other priced arm at or below it; the difference at 0×512 128 reaches p < 0.05. " \
        "0×512 128 (0 of 20) emerged in none of its runs and reads barren: an arm holding no replicator to read."
      )
    end
  end

  describe "the pre-registered rule" do
    let(:complexity_arms) do
      [arm(off, 128, runs: %i[neither neither unmeasured], zero_core: 1),
       arm(priced, 128, runs: %i[rising neither], zero_core: 2),
       arm(steal, 128, runs: %i[plateau plateau plateau], zero_core: 1)]
    end

    it "counts every emerged run it reads no ratio on, measured under the amendment or not" do
      expect(reading).to have_attributes(emerged_count: 8, pre_registered_unmeasured_count: 5)
    end

    it "reads an arm only where two of its runs survive the rule" do
      expect(reading.pre_registered_readable_arms.map(&:label)).to eq(["1024×512 128"])
      expect(reading.pre_registered_sentence)
        .to eq("Under the pre-registered rule 5 of the 8 emerged runs are unmeasured and 1 arm reads.")
    end

    context "with an emerged run in an arm the complexity reading carries no row for" do
      let(:complexity_arms) { [arm(off, 128, runs: %i[neither neither])] }

      before { seed_runs(priced, 128, terminal: 3, emerged: 1) }

      it "counts that run among the emerged runs the rule reads no ratio on" do
        expect(reading.pre_registered_sentence)
          .to eq("Under the pre-registered rule 1 of the 3 emerged runs are unmeasured and 1 arm reads.")
      end
    end

    context "with every emerged run's core at zero" do
      let(:complexity_arms) { [arm(off, 128, runs: %i[neither neither], zero_core: 2)] }

      it "says no arm reads" do
        expect(reading.pre_registered_sentence)
          .to eq("Under the pre-registered rule 2 of the 2 emerged runs are unmeasured and no arm reads.")
      end
    end
  end

  describe "the pooled counts" do
    let(:complexity_arms) do
      [arm(off, 128, runs: %i[rising neither neither]), arm(off, 256, runs: %i[neither]),
       arm(priced, 128, runs: %i[rising neither]), arm(steal, 128, runs: %i[rising plateau neither])]
    end

    it "sums rising and measured runs apart for the priced arms and the controls" do
      expect(reading).to have_attributes(treated_rising_count: 2, treated_measured_count: 5,
                                         control_rising_count: 1, control_measured_count: 4)
    end
  end

  describe "#theft_sentence" do
    context "with theft evolved in every steal arm" do
      let(:complexity_arms) do
        [arm(off, 128, runs: []), arm(steal, 128, runs: [], steals: true, peak: 0.3234),
         arm(steal, 256, runs: [], steals: true, peak: 0.9373), arm(priced, 128, runs: [])]
      end

      it "gives the peak range and says the null is not read" do
        expect(reading.theft_sentence).to eq(
          "Theft evolved in every one of the 2 steal arms, peak steal_rate 0.32–0.94. So no steal arm reads " \
          "the theft-never-evolved null, which would have said nothing about whether theft helps."
        )
      end
    end

    context "with a steal arm whose steal_rate never left zero" do
      let(:complexity_arms) do
        [arm(steal, 128, runs: [], steals: true, peak: 0.0), arm(steal, 256, runs: [], steals: true, peak: 0.5)]
      end

      it "names the arm that reads the null" do
        expect(reading.theft_sentence).to eq(
          "Theft evolved in 1 of the 2 steal arms, peak steal_rate 0.50. 1024×512 128 reads theft never " \
          "evolved: the op was there and no lineage used it, which says nothing about whether theft helps."
        )
      end
    end
  end

  describe "#refutation_sentence" do
    context "with no control plateauing" do
      let(:complexity_arms) do
        [arm(off, 128, runs: %i[neither neither]), arm(off, 256, runs: %i[rising neither neither]),
         arm(priced, 128, runs: %i[plateau plateau])]
      end

      it "says there is no control plateau to match" do
        expect(reading.refutation_sentence).to eq(
          "Checked against the condition as worded: 0 128 reads neither and 0 256 reads neither. " \
          "No economy-off control plateaus, so there is no control plateau for a priced arm to match and " \
          "the condition is not met on these runs."
        )
      end
    end

    context "with every priced arm plateauing where its control does" do
      let(:complexity_arms) do
        [arm(off, 128, runs: %i[plateau plateau]), arm(priced, 128, runs: %i[plateau plateau]),
         arm(steal, 128, runs: [])]
      end

      it "reads the hypothesis as refuted" do
        expect(reading.refutation_sentence).to end_with(
          "Every priced arm plateaus or holds no replicator where its control plateaus, so the condition is met."
        )
        expect(reading).to have_attributes(verdict: :refuted, badge_class: "badge-error")
      end
    end

    context "with a priced arm that does not plateau beside a plateaued control" do
      let(:complexity_arms) do
        [arm(off, 128, runs: %i[plateau plateau]), arm(priced, 128, runs: %i[neither neither])]
      end

      it "names the arm keeping the condition unmet" do
        expect(reading.refutation_sentence)
          .to end_with("The condition is not met: 0×512 128 does not plateau where its control does.")
        expect(reading.verdict).to eq(:not_rising)
      end
    end
  end

  def arm_named(label) = reading.arms.find { |candidate| candidate.label == label }

  # One arm of the sweep in the database, runs and all, and the complexity reading the
  # service would publish for it, built from readings of the named kinds.
  def arm(economy, cap, runs:, terminal: 10, steals: false, peak: nil, zero_core: 0)
    runs_seeded = seed_runs(economy, cap, terminal: terminal, emerged: runs.size)

    Experiments::ComplexityArmsService::Arm.new(
      label: reading_label_of(runs_seeded.first), terminal_count: terminal, steals: steals, peak_steal_rate: peak,
      readings: runs.each_with_index.map { |kind, index| run_reading(kind, zero_core: index < zero_core) }
    )
  end

  def seed_runs(economy, cap, terminal:, emerged:)
    Array.new(terminal) do |index|
      epoch = index < emerged ? 100 : nil
      run = create(:run, experiment: experiment, params: economy.merge("max_tape_len" => cap), status: "finished",
                         transition_epoch: epoch, emergence_epoch: epoch)
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })
      run
    end
  end

  def reading_label_of(run)
    Experiments::Axis.sweep(experiment.reload.param_grid).map { |axis| axis.label_of_run(run.params) }.join(" ")
  end

  def run_reading(kind, zero_core:)
    span = Experiments::ComplexityArmsService::Span
    core = zero_core ? span.new(first: 0, last: 0) : span.new(first: 40, last: 40)
    first, last = { rising: [10, 30], plateau: [10, 10], neither: [10, 5] }[kind]
    instructions = first && span.new(first: first, last: last)

    Experiments::ComplexityArmsService::Reading.new(instructions: instructions, core: core, compressed: nil,
                                                    lineages: nil)
  end
end
