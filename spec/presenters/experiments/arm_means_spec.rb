# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::ArmMeans do
  subject(:means) { described_class.read(axes: axes, runs: experiment.runs.to_a, series: series) }

  let(:experiment) { create(:experiment, param_grid: { "energy_per_epoch" => [0, 2048], "max_tape_len" => [128, 256] }) }
  let(:axes) { Experiments::Axis.sweep(experiment.param_grid) }
  let(:series) { Experiments::ArmSeries::EVERY }

  def run_at(energy, tape, *readings)
    run = create(:run, experiment: experiment, params: { "energy_per_epoch" => energy, "max_tape_len" => tape })
    readings.each { |epoch, values| create(:sample, run: run, epoch: epoch, values: values) }
    run
  end

  # The values are what `AVG(numeric)` returns over each arm's runs, the query this read
  # replaced: a mean is folded across the other axis's arms without losing a digit.
  context "with two swept axes" do
    before do
      run_at(0, 128, [100, { "distinct_lineages" => 1, "top_lineage_share" => 0.1 }])
      run_at(0, 256, [100, { "distinct_lineages" => 1, "top_lineage_share" => 0.25 }])
      run_at(0, 256, [100, { "distinct_lineages" => 2, "top_lineage_share" => 0.3 }],
             [200, { "distinct_lineages" => 4 }])
      run_at(2048, 128, [100, { "distinct_lineages" => 9 }])
    end

    it "averages every arm of every axis at each epoch, to the digit" do
      expect(means.slice(["energy_per_epoch", 0, "distinct_lineages"], ["energy_per_epoch", 0, "top_lineage_share"]))
        .to eq(["energy_per_epoch", 0, "distinct_lineages"] => [[100, BigDecimal("1.3333333333333333")], [200, 4]],
               ["energy_per_epoch", 0, "top_lineage_share"] => [[100, BigDecimal("0.21666666666666666667")]])
    end

    it "folds the runs of one arm across the arms of the other axis" do
      expect(means.slice(["max_tape_len", 0, "distinct_lineages"], ["max_tape_len", 1, "distinct_lineages"],
                         ["energy_per_epoch", 1, "distinct_lineages"]))
        .to eq(["max_tape_len", 0, "distinct_lineages"] => [[100, 5]],
               ["max_tape_len", 1, "distinct_lineages"] => [[100, BigDecimal("1.5")], [200, 4]],
               ["energy_per_epoch", 1, "distinct_lineages"] => [[100, 9]])
    end
  end

  # A sweep holding finished runs beside runs still under way holds the finished runs' sums
  # and adds the others' to them on every read; the mean has to come out as the one pass's.
  context "with finished runs beside runs still under way" do
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }
    let!(:finished) do
      [run_at(0, 128, [100, { "distinct_lineages" => 1, "top_lineage_share" => 0.10 }]),
       run_at(0, 256, [100, { "distinct_lineages" => 1, "top_lineage_share" => 0.25 }])]
    end
    let!(:live) do
      run_at(0, 256, [100, { "distinct_lineages" => 2, "top_lineage_share" => 0.3 }],
             [200, { "distinct_lineages" => 4 }])
    end

    before do
      run_at(2048, 128, [100, { "distinct_lineages" => 9 }])
      finished.each { |run| run.update!(status: "finished") }
      live.update!(status: "running")
      allow(Rails).to receive(:cache).and_return(cache)
    end

    def read = described_class.read(axes: axes, runs: experiment.runs.reload.to_a, series: series)

    it "averages every arm to the digit the one pass does" do
      expect(read.slice(["energy_per_epoch", 0, "distinct_lineages"], ["energy_per_epoch", 0, "top_lineage_share"]))
        .to eq(["energy_per_epoch", 0, "distinct_lineages"] => [[100, BigDecimal("1.3333333333333333")], [200, 4]],
               ["energy_per_epoch", 0, "top_lineage_share"] => [[100, BigDecimal("0.21666666666666666667")]])
    end

    # Postgres divides to at least the scale of its operands: a held sum that lost its
    # trailing zeros on the way back would be divided to fewer digits than the one pass.
    it "divides a held sum to the digits a pass over its samples does" do
      scaled = run_at(0, 128, [700, { "distinct_lineages" => 0 }])
      Sample.where(run: scaled).update_all(Arel.sql(%(values = '{"distinct_lineages": 1.0000000000000000000000}')))
      2.times { run_at(0, 128, [700, { "distinct_lineages" => 0 }]) }
      read_live = read[["max_tape_len", 0, "distinct_lineages"]].assoc(700)
      scaled.update!(status: "finished")

      expect(read[["max_tape_len", 0, "distinct_lineages"]].assoc(700)).to eq(read_live)
      expect(read_live.last).to eq(BigDecimal("0.3333333333333333333333"))
    end

    it "reads the finished runs' samples once" do
      first = read
      Sample.where(run: finished).delete_all

      expect(read).to eq(first)
    end

    it "reads a run still under way afresh" do
      read
      Runs::RecordSamplesService.call(run: live, samples: [{ "epoch" => 300, "distinct_lineages" => 6 }])

      expect(read[["max_tape_len", 1, "distinct_lineages"]]).to eq([[100, BigDecimal("1.5")], [200, 4], [300, 6]])
    end

    it "reads a finished run afresh once it is written to" do
      read
      Sample.where(run: finished.first).update_all(values: { "distinct_lineages" => 7 })
      finished.first.update!(updated_at: Time.current)

      expect(read[["max_tape_len", 0, "distinct_lineages"]]).to eq([[100, 8]])
    end
  end

  context "with readings that are not numbers" do
    before do
      run_at(0, 128, [100, { "dominant_instruction_count" => nil }], [200, { "dominant_instruction_count" => 6 }])
      run_at(0, 128, [100, { "dominant_instruction_count" => "12" }], [200, { "dominant_instruction_count" => 8 }])
    end

    it "leaves them out of the mean, and an epoch holding none of them out of the line" do
      expect(means[["energy_per_epoch", 0, "dominant_instruction_count"]]).to eq([[200, 7]])
    end
  end

  context "with no run at all" do
    it "reads nothing, and asks the database nothing" do
      swept = axes
      queries = []
      collect = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

      ActiveSupport::Notifications.subscribed(collect, "sql.active_record") do
        expect(described_class.read(axes: swept, runs: [], series: series)).to eq({})
      end
      expect(queries).to be_empty
    end
  end
end
