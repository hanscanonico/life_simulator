# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::ComplexitySurvey do
  def transitioned_run(lengths, transition_epoch: 100, instructions: 15, **attributes)
    run = create(:run, status: "finished", transition_epoch: transition_epoch, **attributes)
    lengths.each_with_index do |length, index|
      create(:sample, run: run, epoch: transition_epoch + (index * 10),
                      values: { "dominant_compressed_len" => length, "dominant_instruction_count" => instructions })
    end
    run
  end

  it "rows every transitioned run whose samples carry a complexity" do
    radius = create(:experiment, name: "Radius", slug: "radius")
    world_size = create(:experiment, name: "World size", slug: "world-size")
    transitioned_run([36, 40], experiment: radius)
    transitioned_run([80, 60], experiment: world_size)

    survey = described_class.build

    expect(survey).to have_attributes(transitioned_count: 2, measured_count: 2, compared_count: 2)
    expect(survey.sweeps.map(&:name)).to eq(["Radius", "World size"])
  end

  it "counts the runs whose replicator grew, shrank and stayed the same size" do
    transitioned_run([36, 40, 44])
    transitioned_run([80, 60])
    transitioned_run([36, 36])

    survey = described_class.build

    expect(survey).to have_attributes(grew_count: 1, shrank_count: 1, flat_count: 1)
  end

  it "reads the first, last and largest length of a run after its crossing" do
    transitioned_run([36, 90, 44])

    row = described_class.build.rows.sole

    expect(row).to have_attributes(first_length: 36, last_length: 44, max_length: 90,
                                   first_epoch: 100, last_epoch: 120, readings: 3, direction: :grew)
  end

  it "reads the instruction count of the same samples as the length" do
    run = create(:run, status: "finished", transition_epoch: 100)
    create(:sample, run: run, epoch: 100,
                    values: { "dominant_compressed_len" => 36, "dominant_instruction_count" => 15 })
    create(:sample, run: run, epoch: 200,
                    values: { "dominant_compressed_len" => 44, "dominant_instruction_count" => 21 })

    expect(described_class.build.rows.sole).to have_attributes(first_instructions: 15, last_instructions: 21)
  end

  it "leaves out the samples taken before the crossing" do
    run = create(:run, status: "finished", transition_epoch: 200)
    create(:sample, run: run, epoch: 100, values: { "dominant_compressed_len" => 200 })
    create(:sample, run: run, epoch: 200, values: { "dominant_compressed_len" => 36 })
    create(:sample, run: run, epoch: 300, values: { "dominant_compressed_len" => 36 })

    expect(described_class.build.rows.sole).to have_attributes(first_length: 36, max_length: 36, direction: :flat)
  end

  it "reads no direction off a run with a single reading" do
    transitioned_run([36])

    survey = described_class.build

    expect(survey).to have_attributes(measured_count: 1, compared_count: 0)
    expect(survey.rows.sole).to have_attributes(direction: nil, compared?: false)
  end

  it "rows no run whose samples never carried a complexity" do
    run = transitioned_run([])
    create(:sample, run: run, epoch: 100, values: { "dominant_compressed_len" => nil })
    create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4 })

    expect(described_class.build).to have_attributes(transitioned_count: 1, measured_count: 0, any?: false)
  end

  it "leaves out runs that never transitioned and runs still going" do
    transitioned_run([36, 44])
    create(:sample, run: create(:run, status: "finished", transition_epoch: nil), epoch: 100,
                    values: { "dominant_compressed_len" => 36 })
    create(:sample, run: create(:run, status: "running", transition_epoch: 10), epoch: 100,
                    values: { "dominant_compressed_len" => 36 })

    expect(described_class.build.measured_count).to eq(1)
  end

  it "caps the table and says how many runs it left out" do
    stub_const("Findings::ShowPage::MAX_TRANSITIONS", 1)
    2.times { transitioned_run([36, 44]) }

    survey = described_class.build

    expect(survey).to have_attributes(measured_count: 2, rows_omitted: 1, capped?: true)
    expect(survey.table_rows.size).to eq(1)
  end
end
