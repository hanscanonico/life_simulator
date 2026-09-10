# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::RequeueFailedService do
  let(:experiment) { create(:experiment, status: "running") }

  def failed_run(**attributes)
    create(:run, :claimed, experiment: experiment, status: "failed", started_at: 1.hour.ago,
                           finished_at: 2.minutes.ago, error: "answer body over the limit",
                           epochs_done: 1_200, **attributes)
  end

  it "returns a failed run to the pending queue with its runner columns cleared" do
    run = failed_run

    described_class.call(experiment: experiment)

    expect(run.reload).to have_attributes(status: "pending", runner_id: nil, claimed_at: nil,
                                          heartbeat_at: nil, started_at: nil, finished_at: nil,
                                          error: nil, epochs_done: 0)
  end

  it "returns the number of runs it requeued" do
    2.times { failed_run }

    expect(described_class.call(experiment: experiment)).to eq(2)
  end

  it "leaves the claimed, running and finished runs alone" do
    untouched = [create(:run, :claimed, experiment: experiment),
                 create(:run, :claimed, experiment: experiment, status: "running"),
                 create(:run, :claimed, experiment: experiment, status: "finished", epochs_done: 1_000)]

    described_class.call(experiment: experiment)

    expect(untouched.map { |run| run.reload.status }).to eq(%w[claimed running finished])
  end

  it "leaves the failed runs of another experiment alone" do
    other = create(:run, experiment: create(:experiment), status: "failed")

    described_class.call(experiment: experiment)

    expect(other.reload.status).to eq("failed")
  end

  it "keeps the samples and snapshots the failed run already reported" do
    run = failed_run
    create(:sample, run: run, epoch: 100)
    create(:snapshot, run: run, epoch: 100)

    described_class.call(experiment: experiment)

    expect([run.samples.count, run.snapshots.count]).to eq([1, 1])
  end

  context "with the experiment already closed" do
    it "reopens it so a runner claims the requeued run" do
      experiment.update!(status: "finished")
      failed_run

      described_class.call(experiment: experiment)

      expect(experiment.reload.status).to eq("queued")
    end
  end

  context "with no failed run" do
    it "leaves the experiment status alone" do
      experiment.update!(status: "finished")

      described_class.call(experiment: experiment)

      expect(experiment.reload.status).to eq("finished")
    end
  end
end
