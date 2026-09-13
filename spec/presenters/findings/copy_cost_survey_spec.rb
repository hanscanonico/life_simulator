# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::CopyCostSurvey do
  def transitioned_run(costs, transition_epoch: 100, **attributes)
    run = create(:run, status: "finished", transition_epoch: transition_epoch, **attributes)
    costs.each_with_index do |cost, index|
      create(:sample, run: run, epoch: transition_epoch + (index * 10), values: { "copy_cost" => cost })
    end
    run
  end

  it "rows every transitioned run whose samples carry a copy cost" do
    radius = create(:experiment, name: "Radius", slug: "radius")
    world_size = create(:experiment, name: "World size", slug: "world-size")
    transitioned_run([1_794, 1_500], experiment: radius)
    transitioned_run([900, 1_200], experiment: world_size)

    survey = described_class.build

    expect(survey).to have_attributes(transitioned_count: 2, measured_count: 2, compared_count: 2)
    expect(survey.sweeps.map(&:name)).to eq(["Radius", "World size"])
  end

  it "counts the runs whose cost fell, rose and stayed flat" do
    transitioned_run([1_794, 1_600, 1_500])
    transitioned_run([900, 1_200])
    transitioned_run([1_000, 1_000])

    survey = described_class.build

    expect(survey).to have_attributes(fell_count: 1, rose_count: 1, flat_count: 1)
  end

  it "reads the first, last and smallest cost of a run after its crossing" do
    transitioned_run([1_794, 1_200, 1_500])

    row = described_class.build.rows.sole

    expect(row).to have_attributes(first_cost: 1_794, last_cost: 1_500, min_cost: 1_200,
                                   first_epoch: 100, last_epoch: 120, readings: 3, direction: :fell)
  end

  it "leaves out the samples taken before the crossing" do
    run = create(:run, status: "finished", transition_epoch: 200)
    create(:sample, run: run, epoch: 100, values: { "copy_cost" => 500 })
    create(:sample, run: run, epoch: 200, values: { "copy_cost" => 1_794 })
    create(:sample, run: run, epoch: 300, values: { "copy_cost" => 1_794 })

    expect(described_class.build.rows.sole)
      .to have_attributes(first_cost: 1_794, min_cost: 1_794, direction: :flat)
  end

  it "reads no direction off a run with a single reading" do
    transitioned_run([1_794])

    survey = described_class.build

    expect(survey).to have_attributes(measured_count: 1, compared_count: 0)
    expect(survey.rows.sole).to have_attributes(direction: nil, compared?: false)
  end

  it "rows no run whose samples never carried a cost" do
    run = transitioned_run([])
    create(:sample, run: run, epoch: 100, values: { "copy_cost" => nil })
    create(:sample, run: run, epoch: 200, values: { "compress_ratio" => 0.4 })

    expect(described_class.build).to have_attributes(transitioned_count: 1, measured_count: 0, any?: false)
  end

  it "leaves out runs that never transitioned and runs still going" do
    transitioned_run([1_794, 1_500])
    create(:sample, run: create(:run, status: "finished", transition_epoch: nil), epoch: 100,
                    values: { "copy_cost" => 1_000 })
    create(:sample, run: create(:run, status: "running", transition_epoch: 10), epoch: 100,
                    values: { "copy_cost" => 1_000 })

    expect(described_class.build.measured_count).to eq(1)
  end

  it "caps the table and says how many runs it left out" do
    stub_const("Findings::ShowPage::MAX_TRANSITIONS", 1)
    2.times { transitioned_run([1_794, 1_500]) }

    survey = described_class.build

    expect(survey).to have_attributes(measured_count: 2, rows_omitted: 1, capped?: true)
    expect(survey.table_rows.size).to eq(1)
  end
end
