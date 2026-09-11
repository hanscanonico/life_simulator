# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::RescoreSummary do
  subject(:summary) { described_class.build(experiment: experiment) }

  let(:experiment) { create(:experiment, param_grid: { "radius" => [1, 2] }) }

  context "with no rescore" do
    it "has nothing to report" do
      create(:run, experiment: experiment)

      expect(summary).not_to be_any
      expect(summary.rows).to be_empty
    end
  end

  context "with a corpus pass at two windows" do
    let(:dead_at_baseline) { create(:run, experiment: experiment) }
    let(:alive_at_baseline) { create(:run, experiment: experiment) }

    before do
      create(:rescore, run: dead_at_baseline, epoch: 100, top_k: 16, replicator_count: 0)
      create(:rescore, run: dead_at_baseline, epoch: 200, top_k: 16, replicator_count: 0)
      create(:rescore, run: dead_at_baseline, epoch: 100, top_k: 64, replicator_count: 0)
      create(:rescore, run: dead_at_baseline, epoch: 200, top_k: 64, replicator_count: 4)
      create(:rescore, run: alive_at_baseline, epoch: 100, top_k: 16, replicator_count: 2)
      create(:rescore, run: alive_at_baseline, epoch: 100, top_k: 64, replicator_count: 9)
    end

    it "reports one row per window, in top_k order" do
      expect(summary.rows.map(&:top_k)).to eq([16, 64])
    end

    it "counts the worlds it measured and the runs whose census was not empty" do
      baseline = summary.rows.first

      expect(baseline.worlds).to eq(3)
      expect(baseline.runs_measured).to eq(2)
      expect(baseline.runs_with_replicators).to eq(1)
    end

    it "reads the median and the peak over the readings of the window" do
      wide = summary.rows.last

      expect(wide.median_replicator_count).to eq(4)
      expect(wide.max_replicator_count).to eq(9)
    end

    it "counts the runs the baseline calls dead and the wider window calls alive" do
      expect(summary.rows.map(&:newly_positive_runs)).to eq([nil, 1])
    end

    it "costs the same two queries whatever the sweep holds" do
      queries = 0
      counter = ->(_name, _start, _finish, _id, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { summary.rows }

      expect(queries).to eq(2)
    end

    it "memoises the rows" do
      expect(summary.rows).to be(summary.rows)
    end

    context "with a run measured only at the wider window" do
      it "leaves it out of the newly positive count" do
        unmeasured = create(:run, experiment: experiment)
        create(:rescore, run: unmeasured, epoch: 100, top_k: 64, replicator_count: 5)

        expect(summary.rows.last.newly_positive_runs).to eq(1)
        expect(summary.rows.last.runs_measured).to eq(3)
      end
    end

    context "with a pass that skipped the baseline window" do
      it "counts nothing rather than reporting a zero" do
        Rescore.where(top_k: 16).delete_all

        expect(summary.rows.map(&:top_k)).to eq([64])
        expect(summary.rows.map(&:newly_positive_runs)).to eq([nil])
      end
    end

    context "with another experiment's rescores" do
      it "reads none of them" do
        create(:rescore, epoch: 100, top_k: 256, replicator_count: 7)

        expect(summary.rows.map(&:top_k)).to eq([16, 64])
      end
    end
  end
end
