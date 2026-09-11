# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::TransitionAuditService do
  let(:experiment) { create(:experiment, slug: "bff-control") }
  let(:run) { create(:run, experiment: experiment, status: "finished", transition_epoch: 400) }

  def record(epoch, op_density, compress_ratio: 0.143)
    create(:sample, run: run, epoch: epoch, values: { "compress_ratio" => compress_ratio,
                                                      "op_density" => op_density })
  end

  it "lists a run whose alphabet collapsed after its transition" do
    record(400, 0.27)
    record(600, 1.0)

    report = described_class.call

    expect(report.rows.map(&:run_id)).to eq([run.id])
    expect(report.rows.first.dense_epoch).to eq(600)
    expect(report.to_text).to include("bff-control", "1 of 1 stored transitions would no longer qualify")
  end

  it "leaves out a run that stayed under the guard" do
    record(400, 0.27)
    record(600, 0.31)

    expect(described_class.call.rows).to be_empty
  end

  it "ignores a dense sample from before the transition" do
    record(100, 1.0)
    record(400, 0.27)

    expect(described_class.call.rows).to be_empty
  end

  it "leaves the stored transition_epoch alone" do
    record(400, 1.0)

    expect { described_class.call }.not_to(change { run.reload.transition_epoch })
  end

  it "reads what the guard would make of the run instead" do
    record(400, 1.0)

    expect(described_class.call.rows.first.guarded_epoch).to be_nil
  end

  context "with an experiment given" do
    it "reads only its runs" do
      record(400, 1.0)
      other = create(:run, status: "finished", transition_epoch: 100)
      create(:sample, run: other, epoch: 100, values: { "compress_ratio" => 0.1, "op_density" => 1.0 })

      expect(described_class.call(experiment: experiment).rows.map(&:run_id)).to eq([run.id])
    end
  end

  it "counts the transitions it read" do
    record(400, 0.27)
    create(:run, experiment: experiment, status: "finished")

    expect(described_class.call.to_text).to include("0 of 1 stored transitions would no longer qualify")
  end
end
