# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::RecordSamplesService do
  let(:run) { create(:run, :claimed) }

  def batch(*epochs)
    epochs.map { |epoch| { "epoch" => epoch, "compress_ratio" => epoch / 1_000.0 } }
  end

  it "stores one row per sampled epoch" do
    described_class.call(run: run, samples: batch(100, 200))

    expect(run.samples.order(:epoch).pluck(:epoch)).to eq([100, 200])
  end

  it "summarises the run with the newest sample of the batch" do
    described_class.call(run: run, samples: batch(200, 100))

    expect(run.reload.summary).to eq("compress_ratio" => 0.2)
  end

  it "records the transition epoch the batch carries" do
    described_class.call(run: run, samples: batch(100), transition_epoch: 100)

    expect(run.reload.transition_epoch).to eq(100)
  end

  context "with a batch the runner already posted" do
    it "keeps the summary of the newest sample recorded" do
      described_class.call(run: run, samples: batch(300, 400))
      described_class.call(run: run, samples: batch(100, 200))

      expect(run.reload.summary).to eq("compress_ratio" => 0.4)
    end

    it "stores the conserved core of a lineage the engine reported" do
      described_class.call(run: run, samples: [{ "epoch" => 100, "compress_ratio" => 0.5,
                                                 "conserved_core_bytes" => 36, "conserved_core_ops" => 15 }])

      expect(run.samples.sole.values).to include("conserved_core_bytes" => 36, "conserved_core_ops" => 15)
    end

    it "stores the share of interactions that stole" do
      described_class.call(run: run, samples: [{ "epoch" => 100, "compress_ratio" => 0.5, "steal_rate" => 0.25 }])

      expect(run.samples.sole.values).to include("steal_rate" => 0.25)
    end

    it "still touches the run" do
      described_class.call(run: run, samples: batch(300, 400))

      expect { described_class.call(run: run, samples: batch(100, 200)) }.to(change { run.reload.updated_at })
    end

    it "stores no duplicate rows" do
      described_class.call(run: run, samples: batch(100, 200))

      expect { described_class.call(run: run, samples: batch(100, 200)) }.not_to change(Sample, :count)
    end

    it "still refreshes the metrics of the epochs it re-posts" do
      described_class.call(run: run, samples: batch(100))
      described_class.call(run: run, samples: [{ "epoch" => 100, "compress_ratio" => 0.5 }])

      expect(run.samples.sole.values).to eq("compress_ratio" => 0.5)
    end
  end

  context "with a transition epoch already recorded" do
    it "keeps the earliest of the two" do
      run.update!(transition_epoch: 300)

      described_class.call(run: run, samples: batch(900), transition_epoch: 900)

      expect(run.reload.transition_epoch).to eq(300)
    end

    it "takes an earlier one" do
      run.update!(transition_epoch: 900)

      described_class.call(run: run, samples: batch(300), transition_epoch: 300)

      expect(run.reload.transition_epoch).to eq(300)
    end
  end

  context "with a relative transition epoch already recorded" do
    it "keeps the earliest of the two" do
      run.update!(transition_epoch_relative: 300)

      described_class.call(run: run, samples: batch(900), transition_epoch_relative: 900)

      expect(run.reload.transition_epoch_relative).to eq(300)
    end
  end

  context "with a batch that carries no transition epoch" do
    it "leaves the epoch already recorded alone" do
      run.update!(transition_epoch: 300)

      described_class.call(run: run, samples: batch(400))

      expect(run.reload.transition_epoch).to eq(300)
    end
  end

  context "with an empty batch" do
    it "records nothing" do
      expect { described_class.call(run: run, samples: []) }.not_to change(Sample, :count)
    end
  end

  context "with a descendant" do
    let(:run) { create(:run, :descendant, :claimed) }

    it "records neither transition reading its runner reports" do
      described_class.call(run: run, samples: batch(1_100), transition_epoch: 1_100, transition_epoch_relative: 1_100)

      expect(run.reload).to have_attributes(transition_epoch: nil, transition_epoch_relative: nil)
    end
  end
end
