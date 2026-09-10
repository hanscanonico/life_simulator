# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::RunsCsvService do
  subject(:rows) { CSV.parse(described_class.call(experiment: experiment).to_a.join) }

  let(:experiment) do
    create(:experiment, param_grid: { "radius" => [1, 2, 4], "width" => [128] })
  end

  it "heads the columns with the run, the swept parameters and the observables" do
    expect(rows.first).to eq(
      %w[run_id seed status epochs epochs_done transition_epoch radius] + Sample::OBSERVABLES
    )
  end

  it "writes one row per run, in id order" do
    first = create(:run, experiment: experiment, seed: 7)
    second = create(:run, experiment: experiment, seed: 8)

    expect(rows.drop(1).map(&:first)).to eq([first.id.to_s, second.id.to_s])
  end

  it "takes the observables from the run's summary" do
    create(:run, experiment: experiment, status: "finished", transition_epoch: 900,
                 params: Lab::Schema.run_defaults.merge("radius" => 2),
                 summary: Sample::OBSERVABLES.index_with(0.5).merge("compress_ratio" => 0.42))

    row = rows.last

    expect(row[2..6]).to eq(%w[finished 1000 0 900 2])
    expect(row[7]).to eq("0.42")
  end

  context "with a run that never transitioned" do
    it "leaves its transition epoch empty" do
      create(:run, experiment: experiment, status: "finished")

      expect(rows.last[5]).to be_nil
    end
  end

  context "with a paired axis" do
    let(:experiment) do
      create(:experiment, param_grid: { "size" => [{ "width" => 32, "height" => 32 },
                                                   { "width" => 64, "height" => 64 }] })
    end

    it "names a column per paired key" do
      create(:run, experiment: experiment, params: { "width" => 64, "height" => 64 })

      expect(rows.first[6..7]).to eq(%w[width height])
      expect(rows.last[6..7]).to eq(%w[64 64])
    end
  end
end
