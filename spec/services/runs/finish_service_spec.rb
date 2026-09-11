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

  it "keeps the earlier transition epoch a sample batch already reported" do
    run.update!(transition_epoch: 300)

    described_class.call(run: run, transition_epoch: 900)

    expect(run.reload.transition_epoch).to eq(300)
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

  it "logs the terminal state for the runner log" do
    allow(Rails.logger).to receive(:info)

    described_class.call(run: run)

    expect(Rails.logger).to have_received(:info)
      .with(/event=run_finished run_id=#{run.id} experiment=#{experiment.slug} status=finished epochs_done=/)
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

    it "logs the failure with the error the runner reported" do
      allow(Rails.logger).to receive(:warn)

      described_class.call(run: run, error: "engine panicked")

      expect(Rails.logger).to have_received(:warn)
        .with(/event=run_failed run_id=#{run.id} experiment=#{experiment.slug} error="engine panicked"/)
    end

    it "truncates a runaway error down to one log line" do
      allow(Rails.logger).to receive(:warn)

      described_class.call(run: run, error: "panic\n#{'x' * 500}")

      expect(Rails.logger).to have_received(:warn).with(a_string_including('error="panic\\n'))
      expect(Rails.logger).to have_received(:warn).with(satisfy { |line| line.length < 300 })
    end

    it "still lets the experiment finish" do
      described_class.call(run: run, error: "engine panicked")

      expect(experiment.reload).to be_finished
    end
  end
end
