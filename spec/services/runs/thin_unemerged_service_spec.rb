# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runs::ThinUnemergedService do
  let(:experiment) { create(:experiment) }

  # A finished founding run whose stored worlds at `epochs` the corpus pass has all read.
  def read_run(epochs = [0, 1_000, 2_000, 3_000], experiment: self.experiment, **attributes)
    run = create(:run, experiment: experiment, status: "finished", epochs: epochs.max, **attributes)
    insert_snapshots(run, epochs)
    epochs.each { |epoch| read(run, epoch) }
    run
  end

  def read(run, epoch, instrument: "oriented_census/1", share: 0.1)
    create(:snapshot_reading, run: run, instrument: instrument, epoch: epoch, source_epoch: epoch,
                              values: { "replicator_share" => share })
  end

  def kept(run) = run.snapshots.order(:epoch).pluck(:epoch)

  def thin(**) = described_class.call(dry_run: false, **)

  it "keeps the first and the last world of a run that never crossed" do
    run = read_run

    thin

    expect(kept(run)).to eq([0, 3_000])
  end

  it "counts the runs, the snapshots and the bytes it deleted" do
    read_run
    world = "world-bytes".bytesize + "png-bytes".bytesize

    expect(thin.total).to eq(described_class::Tally.new(runs: 1, snapshots: 2, bytes: 2 * world))
  end

  it "counts per experiment slug" do
    read_run
    other = create(:experiment)
    read_run(experiment: other)

    expect(thin.by_experiment.transform_values(&:snapshots)).to eq(experiment.slug => 2, other.slug => 2)
  end

  it "keeps every reading" do
    run = read_run

    expect { thin }.not_to(change { run.snapshot_readings.count })
  end

  it "thins a failed run" do
    run = read_run(status: "failed")

    thin

    expect(kept(run)).to eq([0, 3_000])
  end

  describe "the runs it leaves alone" do
    {
      "an emerged run" => { emergence_epoch: 1_000, emergence_witness: "census" },
      "a run that crossed the constant threshold" => { transition_epoch: 1_000 },
      "a run that crossed the relative threshold" => { transition_epoch_relative: 1_000 },
      "a running run" => { status: "running" },
      "a pending run" => { status: "pending" }
    }.each do |label, attributes|
      it "leaves #{label}, and counts none of it in a dry run" do
        run = read_run(**attributes)

        counted = described_class.call.total.snapshots
        thin

        expect([counted, kept(run)]).to eq([0, [0, 1_000, 2_000, 3_000]])
      end
    end

    it "leaves an experiment oriented_census/1 has not read, whatever else has" do
      run = create(:run, experiment: experiment, status: "finished", epochs: 3_000)
      insert_snapshots(run, [0, 1_000, 2_000, 3_000])
      [0, 1_000, 2_000, 3_000].each { |epoch| read(run, epoch, instrument: "oriented_census/2") }

      thin

      expect(kept(run)).to eq([0, 1_000, 2_000, 3_000])
    end

    it "leaves a descendant run" do
      parent = read_run
      child = create(:run, experiment: experiment, status: "finished", parent_run: parent, parent_epoch: 3_000,
                           epochs: 6_000)
      insert_snapshots(child, [4_000, 5_000, 6_000])
      [4_000, 5_000, 6_000].each { |epoch| read(child, epoch) }

      thin

      expect(kept(child)).to eq([4_000, 5_000, 6_000])
    end

    it "leaves the parent of a descendant" do
      parent = read_run
      create(:run, experiment: experiment, parent_run: parent, parent_epoch: 1_000, epochs: 2_000)

      thin

      expect(kept(parent)).to eq([0, 1_000, 2_000, 3_000])
    end

    it "leaves an excluded experiment" do
      run = read_run
      stub_const("#{described_class}::EXCLUDED_EXPERIMENTS", [experiment.slug])

      thin

      expect(kept(run)).to eq([0, 1_000, 2_000, 3_000])
    end
  end

  describe "the worlds it keeps" do
    it "keeps a world the corpus pass has not read" do
      run = read_run
      insert_snapshots(run, [1_500])

      thin

      expect(kept(run)).to eq([0, 1_500, 3_000])
    end

    it "keeps a world read only by a reading stepped onto it" do
      run = read_run([0, 3_000])
      insert_snapshots(run, [1_000])
      create(:snapshot_reading, run: run, epoch: 1_000, source_epoch: 990)

      thin

      expect(kept(run)).to eq([0, 1_000, 3_000])
    end

    it "keeps a world another instrument of its experiment has not read" do
      run = read_run
      read(read_run, 1_000, instrument: "oriented_census/2")
      read(run, 2_000, instrument: "oriented_census/2")

      thin

      expect(kept(run)).to eq([0, 1_000, 3_000])
    end

    it "measures the first and last restorable world as the ends" do
      run = read_run
      Snapshot.where(run: run, epoch: 3_000).update_all(blob: nil)

      thin

      expect(kept(run)).to eq([0, 2_000, 3_000])
    end
  end

  describe "a run that changes between its reading and its delete" do
    def changing(run, &change)
      allow(described_class).to receive(:intermediate_worlds).and_wrap_original do |original, *args|
        original.call(*args).tap { change.call(run) }
      end
    end

    {
      "requeued" => ->(run) { run.update!(status: "pending") },
      "backfilled with a crossing" => ->(run) { run.update!(transition_epoch: 1_000) },
      "confirmed emerged" => ->(run) { run.update!(emergence_epoch: 1_000, emergence_witness: "census") }
    }.each do |label, change|
      it "deletes nothing of a run #{label} mid-batch, and counts nothing" do
        run = read_run
        changing(run, &change)

        result = thin

        expect([kept(run), result.total]).to eq([[0, 1_000, 2_000, 3_000], described_class::Tally.zero])
      end
    end

    it "deletes nothing of a run given a descendant mid-batch" do
      run = read_run
      changing(run) { create(:run, experiment: experiment, parent_run: run, parent_epoch: 3_000, epochs: 4_000) }

      thin

      expect(kept(run)).to eq([0, 1_000, 2_000, 3_000])
    end
  end

  describe "a run with few worlds" do
    it "leaves a run with a single stored world" do
      run = read_run([3_000])

      expect([thin.total.runs, kept(run)]).to eq([0, [3_000]])
    end

    it "leaves a run with two stored worlds" do
      run = read_run([0, 3_000])

      expect([thin.total.runs, kept(run)]).to eq([0, [0, 3_000]])
    end

    it "leaves a run with no restorable world" do
      run = read_run([0, 1_000, 3_000])
      Snapshot.where(run: run).update_all(blob: nil)

      expect([thin.total.runs, kept(run)]).to eq([0, [0, 1_000, 3_000]])
    end
  end

  describe "the rows it never deletes" do
    it "keeps a png-only row between the ends" do
      run = read_run
      Snapshot.where(run: run, epoch: 2_000).update_all(blob: nil)

      thin

      expect(kept(run)).to eq([0, 2_000, 3_000])
    end

    it "keeps the world at the run's last epoch, the one a descendant sweep starts from" do
      run = read_run

      thin

      expect(Snapshot.restorable.joins(:run).where(run: run).where("snapshots.epoch = runs.epochs").count).to eq(1)
    end

    it "keeps every sample and rescore of a thinned run" do
      run = read_run
      create(:sample, run: run, epoch: 1_000)
      create(:rescore, run: run, epoch: 1_000)

      expect { thin }.not_to(change { [run.samples.count, run.rescores.count] })
    end
  end

  context "with a dry run" do
    it "deletes nothing" do
      run = read_run

      described_class.call(dry_run: true)

      expect(kept(run)).to eq([0, 1_000, 2_000, 3_000])
    end

    it "counts what it would delete" do
      read_run

      expect(described_class.call.total.snapshots).to eq(2)
    end
  end

  describe "the batch limit" do
    it "stops after max_runs thinned runs, and the next call resumes" do
      runs = Array.new(3) { read_run }

      first = thin(max_runs: 2)
      second = thin(max_runs: 2)

      expect([first.total.runs, first.complete, second.total.runs, second.complete, runs.map { |run| kept(run).size }])
        .to eq([2, false, 1, true, [2, 2, 2]])
    end

    it "thins one run before a spent time limit stops it" do
      2.times { read_run }

      result = thin(time_limit: 0)

      expect([result.total.runs, result.complete]).to eq([1, false])
    end
  end

  describe "the readings off a thinned run" do
    it "leaves a run's oriented summary measured and unchanged" do
      run = read_run
      summary = -> { Runs::OrientedSummariesService.call(runs: [run.reload]).fetch(run.id) }
      before = summary.call

      thin

      after = summary.call
      expect([after.measured?, after.readings, after.unread_worlds, after.peak_share, after.terminal_share])
        .to eq([true, before.readings, 0, before.peak_share, before.terminal_share])
    end

    it "leaves a run with an unread world unmeasured" do
      run = read_run
      insert_snapshots(run, [1_500])

      thin

      summary = Runs::OrientedSummariesService.call(runs: [run.reload]).fetch(run.id)
      expect([summary.measured?, summary.unread_worlds]).to eq([false, 1])
    end

    it "leaves the oriented CSV and the readings CSV unchanged" do
      read_run
      read_run(transition_epoch: 1_000)
      csvs = lambda do
        [Experiments::OrientedCsvService.call(experiment: experiment).to_a,
         Experiments::ReadingsCsvService.call(experiment: experiment, instrument: "oriented_census/1").to_a]
      end
      before = csvs.call

      thin

      expect(csvs.call).to eq(before)
    end

    it "leaves the reach-cap128 reading unchanged" do
      reach = reach_cap128_experiment
      control = host_parasite_control_experiment
      [reach_run(reach, shares: [0.0, 0.6, 0.2]), reach_run(reach, crossing: 1_000, shares: [0.0, 0.6, 0.6]),
       control_run(control, shares: [0.0, 0.3, 0.1]), reach_run(reach, shares: [0.0, 0.1, 0.1], unread: true)]
      report = -> { Experiments::ReachCap128ReadingService.call(experiment: reach) }
      before = report.call

      expect(thin.total.snapshots).to eq(3)
      expect(report.call).to eq(before)
    end
  end
end
