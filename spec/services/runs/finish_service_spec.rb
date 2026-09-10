# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::FinishService do
  let(:experiment) { create(:experiment, status: "running") }
  let(:run) { create(:run, :claimed, experiment: experiment) }

  it "finishes the run" do
    described_class.call(run: run, transition_epoch: 900, summary: { "compress_ratio" => 0.3 })

    expect(run.reload).to have_attributes(status: "finished", transition_epoch: 900, finished_at: be_present)
  end

  it "credits the run with its whole epoch budget, past the last heartbeat" do
    run.update!(epochs: 20_000, epochs_done: 19_342)

    described_class.call(run: run)

    expect(run.reload.epochs_done).to eq(20_000)
  end

  it "finishes the experiment once no run is outstanding" do
    described_class.call(run: run)

    expect(experiment.reload).to be_finished
  end

  it "leaves the experiment running while another run is outstanding" do
    create(:run, experiment: experiment)

    described_class.call(run: run)

    expect(experiment.reload).to be_running
  end

  context "with an error reported" do
    it "fails the run" do
      described_class.call(run: run, error: "engine panicked")

      expect(run.reload).to have_attributes(status: "failed", error: "engine panicked")
    end

    it "leaves the progress the runner reported alone" do
      run.update!(epochs: 20_000, epochs_done: 19_342)

      described_class.call(run: run, error: "engine panicked")

      expect(run.reload.epochs_done).to eq(19_342)
    end

    it "still lets the experiment finish" do
      described_class.call(run: run, error: "engine panicked")

      expect(experiment.reload).to be_finished
    end
  end
end
