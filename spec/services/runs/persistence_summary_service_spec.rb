# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::PersistenceSummaryService do
  let(:run) { create(:run, status: "finished", transition_epoch: 20) }

  def record(series)
    series.each_with_index do |values, index|
      values = { "compress_ratio" => values } if values.is_a?(Numeric)
      create(:sample, run: run, epoch: index * 10, values: values)
    end
  end

  it "reports nothing for a run the detector never flagged" do
    run.update!(transition_epoch: nil)
    record([0.94, 0.94, 0.94])

    expect(described_class.call(run: run)).to be_nil
  end

  it "reports nothing for a flagged run with no samples" do
    expect(described_class.call(run: run)).to be_nil
  end

  it "counts the epochs from the transition to the last sample of a run that holds" do
    record([0.94, 0.94, 0.5, 0.4, 0.3, 0.2])

    summary = described_class.call(run: run)

    expect(summary.epochs_persisted).to eq(30)
    expect(summary).not_to be_relapsed
  end

  it "does not call a single sample back above the threshold a relapse" do
    record([0.94, 0.94, 0.5, 0.4, 0.94, 0.3, 0.2])

    summary = described_class.call(run: run)

    expect(summary.epochs_persisted).to eq(40)
    expect(summary).not_to be_relapsed
  end

  context "with a world back above the threshold for exactly the tracker's hold" do
    it "waits for one sample more than the hold before calling a relapse" do
      hold = Lab::TransitionRule::HOLD_SAMPLES
      record([0.5, 0.4] + ([0.94] * hold) + [0.3, 0.2])
      run.update!(transition_epoch: 0)

      summary = described_class.call(run: run)

      expect(summary).not_to be_relapsed
      expect(summary.epochs_persisted).to eq((hold + 3) * 10)
    end

    it "calls the relapse on the very next sample" do
      record([0.5, 0.4] + ([0.94] * (Lab::TransitionRule::HOLD_SAMPLES + 1)))
      run.update!(transition_epoch: 0)

      summary = described_class.call(run: run)

      expect(summary).to be_relapsed
      expect(summary.epochs_persisted).to eq(10)
    end
  end

  context "with a world that climbs back above the threshold and stays there" do
    it "flags the relapse and stops the count at the last transitioned sample" do
      record([0.94, 0.94, 0.5, 0.4, 0.3, 0.9, 0.93, 0.94, 0.95, 0.95])

      summary = described_class.call(run: run)

      expect(summary.epochs_persisted).to eq(20)
      expect(summary).to be_relapsed
    end
  end

  # The radius-2 run of the design record (2026-09-11): flagged at 12 330, back above the
  # 0.6 line roughly two thousand epochs later, ending where the censored runs end.
  it "flags the design record's radius-2 relapse" do
    run.update!(transition_epoch: 12_330)
    values = ([0.94] * 1233) + ([0.3] * 200) + ([0.9] * 500)
    values.each_with_index { |ratio, index| create(:sample, run: run, epoch: index * 10, values: { "compress_ratio" => ratio }) }

    summary = described_class.call(run: run)

    expect(summary.epochs_persisted).to eq(1_990)
    expect(summary).to be_relapsed
  end

  # The `mutation-rate-long` 2^-12 seed 10 run of the design record (2026-09-11): flagged
  # at 21 540, census peak 123 at 28 100, back to compress_ratio 0.952 by 60 000.
  it "flags the design record's mutation-rate-long relapse and keeps its census peak" do
    run.update!(transition_epoch: 21_540)
    series = ([0.94] * 2154) + ([0.2] * 1000) + ([0.95] * 2846)
    series.each_with_index do |ratio, index|
      values = { "compress_ratio" => ratio }
      values["replicator_count"] = 123 if index == 2810
      create(:sample, run: run, epoch: index * 10, values: values)
    end

    summary = described_class.call(run: run)

    expect(summary).to have_attributes(census_peak: 123, peak_epoch: 28_100, epochs_persisted: 9_990)
    expect(summary).to be_relapsed
  end

  it "reads the census peak and its epoch off the whole series" do
    record([{ "compress_ratio" => 0.94, "replicator_count" => 0 },
            { "compress_ratio" => 0.5, "replicator_count" => 12 },
            { "compress_ratio" => 0.4, "replicator_count" => 123 },
            { "compress_ratio" => 0.3, "replicator_count" => 40 },
            { "compress_ratio" => 0.2, "replicator_count" => 7 }])

    summary = described_class.call(run: run)

    expect(summary.census_peak).to eq(123)
    expect(summary.peak_epoch).to eq(20)
    expect(summary).to be_counted
  end

  it "leaves the peak epoch blank for a census that never left zero" do
    record([{ "compress_ratio" => 0.5, "replicator_count" => 0 },
            { "compress_ratio" => 0.4, "replicator_count" => 0 }])
    run.update!(transition_epoch: 0)

    summary = described_class.call(run: run)

    expect(summary.census_peak).to eq(0)
    expect(summary.peak_epoch).to be_nil
    expect(summary).not_to be_counted
  end

  it "reads the alphabet guard the way the tracker does" do
    record([{ "compress_ratio" => 0.5, "op_density" => 0.2 },
            { "compress_ratio" => 0.4, "op_density" => 0.2 },
            { "compress_ratio" => 0.3, "op_density" => 1.0 },
            { "compress_ratio" => 0.2, "op_density" => 1.0 },
            { "compress_ratio" => 0.1, "op_density" => 1.0 },
            { "compress_ratio" => 0.1, "op_density" => 1.0 }])
    run.update!(transition_epoch: 0)

    summary = described_class.call(run: run)

    expect(summary.epochs_persisted).to eq(10)
    expect(summary).to be_relapsed
  end
end
