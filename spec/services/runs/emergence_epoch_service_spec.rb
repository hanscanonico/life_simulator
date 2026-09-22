# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::EmergenceEpochService do
  let(:run) { create(:run, status: "finished", transition_epoch: 100, transition_epoch_constant: 100) }

  def record(values_by_epoch)
    values_by_epoch.each { |epoch, values| create(:sample, run: run, epoch: epoch, values: values) }
  end

  it "confirms a crossing the replicator census backs within the window" do
    record(100 => { "replicator_count" => 0 }, 110 => { "replicator_count" => 12 })

    expect(described_class.call(run: run)).to have_attributes(epoch: 100, witness: "census", confirmed?: true)
  end

  it "confirms a crossing only the copy rate backs" do
    record(100 => { "replicator_count" => 0, "copy_rate" => 0.0 },
           110 => { "replicator_count" => 0, "copy_rate" => 0.02 })

    expect(described_class.call(run: run)).to have_attributes(epoch: 100, witness: "copy_rate")
  end

  it "confirms nothing for a crossing no witness backs" do
    record(100 => { "replicator_count" => 0, "copy_rate" => 0.0 },
           110 => { "replicator_count" => 0, "copy_rate" => 0.0 })

    expect(described_class.call(run: run)).to have_attributes(epoch: nil, witness: nil, confirmed?: false)
  end

  it "confirms nothing for a run the detector never flagged" do
    run.update!(transition_epoch: nil, transition_epoch_constant: nil)
    record(100 => { "replicator_count" => 12 })

    expect(described_class.call(run: run)).to have_attributes(epoch: nil, witness: nil)
  end

  it "reads the census before the crossing, up to the width of the window" do
    (0..10).each { |index| create(:sample, run: run, epoch: index * 10, values: { "replicator_count" => 0 }) }
    run.samples.find_by(epoch: 0).update!(values: { "replicator_count" => 5 })

    expect(described_class.call(run: run)).to have_attributes(epoch: 100, witness: "census")
  end

  it "reads no witness further from the crossing than the window" do
    (0..21).each { |index| create(:sample, run: run, epoch: index * 10, values: { "replicator_count" => 0 }) }
    run.samples.find_by(epoch: 210).update!(values: { "replicator_count" => 5 })

    expect(described_class.call(run: run)).to have_attributes(epoch: nil, witness: nil)
  end

  it "confirms nothing for a flagged run nothing was ever sampled from" do
    expect(described_class.call(run: run)).to have_attributes(epoch: nil, witness: nil)
  end

  # The relocked `transition_epoch` reads the run's own baseline, which judges no crossing
  # inside that window and no later one against an uncontaminated baseline, so the
  # candidates stay the constant rule's (docs/design_record.md, 2026-09-21).
  it "reads the crossing series the companion rule holds, not the relocked epoch" do
    run.update!(transition_epoch: nil)
    record(100 => { "replicator_count" => 12 })

    expect(described_class.call(run: run)).to have_attributes(epoch: 100, witness: "census")
  end

  it "reads the samples a caller has already loaded rather than the database" do
    emergence = described_class.call(transition_epoch: 100, samples: [[100, { "replicator_count" => 3 }]])

    expect(emergence).to have_attributes(epoch: 100, witness: "census")
  end

  # Run 543's shape (max-tape-len, 512, seed 17): the initial-condition false positive
  # every 512-arm run trips, the soup back above the threshold, then a world that is alive
  # from epoch 12 700 on (docs/design_record.md, 2026-09-15).
  context "with a false first crossing and a live second one" do
    let(:series) do
      (0..20_000).step(100).map do |epoch|
        [epoch, { "compress_ratio" => ratio_at(epoch), "op_density" => 0.1, "alphabet_size" => 200,
                  "replicator_count" => epoch >= 12_700 ? 12 : 0, "copy_rate" => epoch >= 12_700 ? 0.01 : 0.0 }]
      end
    end

    it "confirms the second crossing against the census" do
      expect(described_class.call(transition_epoch: 600, samples: series))
        .to have_attributes(epoch: 12_500, witness: "census", confirmed?: true)
    end

    def ratio_at(epoch)
      return 0.45 if epoch.between?(600, 900)
      return 0.22 if epoch >= 12_500

      0.96
    end
  end

  context "with two crossings and no witness at either" do
    it "confirms nothing" do
      series = (0..3_000).step(100).map do |epoch|
        ratio = epoch.between?(600, 900) || epoch >= 2_000 ? 0.45 : 0.96
        [epoch, { "compress_ratio" => ratio, "replicator_count" => 0, "copy_rate" => 0.0 }]
      end

      expect(described_class.call(transition_epoch: 600, samples: series))
        .to have_attributes(epoch: nil, witness: nil)
    end
  end

  # What keeps every epoch already confirmed where it is: a crossing the samples hold
  # before the one the detector stored is never a candidate.
  context "with a witness at a crossing earlier than the one the detector stored" do
    it "confirms nothing, the earlier crossing being none of its candidates" do
      series = (0..3_000).step(100).map do |epoch|
        ratio = epoch <= 300 || epoch >= 2_000 ? 0.45 : 0.96
        [epoch, { "compress_ratio" => ratio, "op_density" => 0.1, "alphabet_size" => 200,
                  "replicator_count" => epoch <= 300 ? 9 : 0, "copy_rate" => 0.0 }]
      end

      expect(described_class.call(transition_epoch: 2_000, samples: series))
        .to have_attributes(epoch: nil, witness: nil)
    end
  end

  context "with a witness at both crossings" do
    it "confirms the crossing the detector stored, as it did before later crossings were read" do
      series = (0..3_000).step(100).map do |epoch|
        ratio = epoch.between?(600, 900) || epoch >= 2_000 ? 0.45 : 0.96
        [epoch, { "compress_ratio" => ratio, "replicator_count" => 4, "copy_rate" => 0.01 }]
      end

      expect(described_class.call(transition_epoch: 600, samples: series))
        .to have_attributes(epoch: 600, witness: "census")
    end
  end
end
