# frozen_string_literal: true

require "rails_helper"

RSpec.describe Findings::PersistenceSurvey do
  def transitioned_run(persistence:, transition_epoch: 100, samples_after: 4, **attributes)
    run = create(:run, status: "finished", transition_epoch: transition_epoch,
                       persistence: persistence.stringify_keys, **attributes)
    samples_after.times { |index| create(:sample, run: run, epoch: transition_epoch + (index * 10)) }
    run
  end

  it "rows every terminal run that transitioned, whichever sweep it came from" do
    radius = create(:experiment, name: "Radius", slug: "radius")
    world_size = create(:experiment, name: "World size", slug: "world-size")
    transitioned_run(experiment: radius, persistence: { census_peak: 3, peak_epoch: 120,
                                                        epochs_persisted: 40, relapsed: false })
    transitioned_run(experiment: world_size, persistence: { census_peak: 9, peak_epoch: 150,
                                                            epochs_persisted: 80, relapsed: true })

    survey = described_class.build

    expect(survey.transitioned_count).to eq(2)
    expect(survey.sweeps.map(&:name)).to eq(["Radius", "World size"])
  end

  it "leaves out runs that never transitioned and runs still going" do
    transitioned_run(persistence: { census_peak: 1, peak_epoch: 110, epochs_persisted: 30, relapsed: false })
    create(:run, status: "finished", transition_epoch: nil)
    create(:run, status: "running", transition_epoch: 100)

    expect(described_class.build.transitioned_count).to eq(1)
  end

  it "counts a failed run that transitioned before it died" do
    transitioned_run(status: "failed", persistence: { census_peak: 0, peak_epoch: nil,
                                                      epochs_persisted: 10, relapsed: false })

    expect(described_class.build.transitioned_count).to eq(1)
  end

  it "splits the summarised runs into persisters and relapsers" do
    transitioned_run(persistence: { census_peak: 3, peak_epoch: 120, epochs_persisted: 40, relapsed: false })
    transitioned_run(persistence: { census_peak: 9, peak_epoch: 150, epochs_persisted: 80, relapsed: true })
    transitioned_run(persistence: { census_peak: 2, peak_epoch: 130, epochs_persisted: 20, relapsed: true })

    survey = described_class.build

    expect(survey.summarised_count).to eq(3)
    expect(survey.outcome).to have_attributes(persisted_count: 1, relapsed_count: 2, relapse_share: 2.0 / 3)
  end

  it "counts a transitioned run without a summary in neither half" do
    transitioned_run(persistence: {})

    survey = described_class.build

    expect(survey).to have_attributes(transitioned_count: 1, summarised_count: 0)
    expect(survey.outcome).to have_attributes(persisted_count: 0, relapsed_count: 0, relapse_share: nil)
  end

  it "reads the spread of epochs persisted off the summaries" do
    [10, 90, 50].each do |epochs|
      transitioned_run(persistence: { census_peak: 1, peak_epoch: 110, epochs_persisted: epochs,
                                      relapsed: false })
    end

    survey = described_class.build

    expect(survey).to have_attributes(shortest_persistence: 10, median_persistence: 50,
                                      longest_persistence: 90)
  end

  it "reads the census peaks off the runs that counted a replicator" do
    transitioned_run(persistence: { census_peak: 123, peak_epoch: 140, epochs_persisted: 40, relapsed: true })
    transitioned_run(persistence: { census_peak: 7, peak_epoch: 120, epochs_persisted: 40, relapsed: false })
    transitioned_run(persistence: { census_peak: 0, peak_epoch: nil, epochs_persisted: 40, relapsed: false })

    survey = described_class.build

    expect(survey).to have_attributes(median_census: 7, smallest_census: 7, largest_census: 123)
    expect(survey.counted_outcome.count).to eq(2)
  end

  it "splits both outcomes by whether the census ever saw a colony" do
    transitioned_run(persistence: { census_peak: 123, peak_epoch: 140, epochs_persisted: 40, relapsed: true })
    transitioned_run(persistence: { census_peak: 7, peak_epoch: 120, epochs_persisted: 40, relapsed: false })
    transitioned_run(persistence: { census_peak: 0, peak_epoch: nil, epochs_persisted: 40, relapsed: true })
    transitioned_run(persistence: { census_peak: 0, peak_epoch: nil, epochs_persisted: 40, relapsed: true })
    transitioned_run(persistence: { census_peak: nil, peak_epoch: nil, epochs_persisted: 40, relapsed: false })
    transitioned_run(persistence: {})

    survey = described_class.build

    expect(survey.counted_outcome).to have_attributes(count: 2, persisted_count: 1, relapsed_count: 1)
    expect(survey.uncounted_outcome).to have_attributes(count: 3, persisted_count: 1, relapsed_count: 2)
  end

  it "names the persisters too short after their crossing for an exit to be confirmed" do
    transitioned_run(samples_after: Runs::PersistenceSummaryService::EXIT_SAMPLES,
                     persistence: { census_peak: 1, peak_epoch: 110, epochs_persisted: 40, relapsed: false })
    transitioned_run(samples_after: Runs::PersistenceSummaryService::EXIT_SAMPLES - 1,
                     persistence: { census_peak: 1, peak_epoch: 110, epochs_persisted: 10, relapsed: false })

    survey = described_class.build

    expect(survey.outcome.persisted_count).to eq(2)
    expect(survey.unconfirmable_count).to eq(1)
    expect(survey.rows.map(&:relapse_confirmable?)).to eq([true, false])
  end

  it "counts only samples from the crossing onwards towards a confirmable exit" do
    run = create(:run, status: "finished", transition_epoch: 500,
                       persistence: { "census_peak" => 1, "peak_epoch" => 510,
                                      "epochs_persisted" => 40, "relapsed" => false })
    Runs::PersistenceSummaryService::EXIT_SAMPLES.times { |index| create(:sample, run: run, epoch: index * 10) }

    expect(described_class.build.unconfirmable_count).to eq(1)
  end

  it "rows every transitioned run rather than a page of them" do
    3.times do
      transitioned_run(persistence: { census_peak: 1, peak_epoch: 110, epochs_persisted: 40, relapsed: false })
    end

    survey = described_class.build

    expect(survey.rows.size).to eq(3)
    expect(survey.rows.map(&:seed)).to eq(survey.rows.map { |row| row.run.seed })
  end

  it "hands a row the run facts the table states" do
    run = transitioned_run(transition_epoch: 700,
                           persistence: { census_peak: 0, peak_epoch: nil, epochs_persisted: 40,
                                          relapsed: false })

    row = described_class.build.rows.first

    expect(row).to have_attributes(seed: run.seed, transition_epoch: 700, census_sampled?: true,
                                   counted?: false)
  end

  it "says plainly that it has nothing to survey" do
    expect(described_class.build).to have_attributes(any?: false, transitioned_count: 0,
                                                     median_persistence: nil, median_census: nil)
  end
end
