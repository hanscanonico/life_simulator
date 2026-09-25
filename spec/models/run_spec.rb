# frozen_string_literal: true

require "rails_helper"

RSpec.describe Run, type: :model do
  subject(:run) { build(:run) }

  it { is_expected.to belong_to(:experiment) }
  it { is_expected.to belong_to(:parent_run).class_name("Run").optional }
  it { is_expected.to have_many(:descendants).class_name("Run").dependent(:restrict_with_exception) }
  it { is_expected.to have_many(:samples).dependent(:destroy) }
  it { is_expected.to have_many(:snapshots).dependent(:destroy) }
  it { is_expected.to validate_numericality_of(:epochs).only_integer.is_greater_than(0) }

  describe "indexes" do
    let(:indexes) { described_class.connection.indexes(described_class.table_name) }

    it "indexes heartbeat_at for the status page's live runners" do
      expect(indexes.map(&:columns)).to include(["heartbeat_at"])
    end

    it "indexes finished_at for the terminal runs the pruner walks" do
      index = indexes.find { |candidate| candidate.name == "index_runs_on_finished_at_terminal" }
      terminal = Run::TERMINAL_STATUSES.map { |status| a_string_including("'#{status}'") }

      expect(index).to have_attributes(columns: ["finished_at"], where: terminal.reduce(:and))
    end
  end

  describe ".stale" do
    it "includes a claimed run whose heartbeat is older than the stale window" do
      stale = create(:run, :stale)

      expect(described_class.stale).to contain_exactly(stale)
    end

    it "excludes a run that heartbeated recently" do
      create(:run, :claimed)

      expect(described_class.stale).to be_empty
    end

    it "excludes a finished run" do
      create(:run, status: "finished", heartbeat_at: 1.hour.ago)

      expect(described_class.stale).to be_empty
    end
  end

  describe ".emerged" do
    it "includes a terminal run whose crossing a witness confirmed" do
      emerged = create(:run, :emerged)

      expect(described_class.emerged).to contain_exactly(emerged)
    end

    it "excludes a run the detector flagged with no witness behind it" do
      create(:run, status: "finished", transition_epoch: 600)

      expect(described_class.emerged).to be_empty
    end

    it "excludes a run still under way, confirmed or not" do
      create(:run, :emerged, status: "running")

      expect(described_class.emerged).to be_empty
    end

    it "includes a failed run that emerged before its runner died" do
      failed = create(:run, :emerged, status: "failed")

      expect(described_class.emerged).to contain_exactly(failed)
    end
  end

  describe "#claimed_by?" do
    it "is true for the runner holding the run" do
      expect(build(:run, :claimed, runner_id: "runner-7").claimed_by?("runner-7")).to be(true)
    end

    it "is false for another runner" do
      expect(build(:run, :claimed, runner_id: "runner-7").claimed_by?("runner-8")).to be(false)
    end

    context "with no runner holding the run" do
      it "is false" do
        expect(build(:run).claimed_by?(nil)).to be(false)
      end
    end
  end

  describe "#persistence_summary" do
    it "reads the stored summary" do
      run = build(:run, persistence: { "census_peak" => 108, "peak_epoch" => 9_580,
                                       "epochs_persisted" => 12_000, "relapsed" => true })

      expect(run.persistence_summary).to have_attributes(census_peak: 108, peak_epoch: 9_580,
                                                         epochs_persisted: 12_000, relapsed: true)
    end

    it "is nothing for a run nothing has summarised" do
      expect(build(:run).persistence_summary).to be_nil
    end
  end

  describe "#terminal?" do
    it "is true for a failed run" do
      expect(build(:run, status: "failed")).to be_terminal
    end

    it "is false for a running run" do
      expect(build(:run, status: "running")).not_to be_terminal
    end
  end

  describe ".founding" do
    it "holds the runs started from their own initial state, not their descendants" do
      descendant = create(:run, :descendant)

      expect(described_class.founding).to contain_exactly(descendant.parent_run)
    end
  end

  describe "a descendant in the transition surveys" do
    let!(:descendant) { create(:run, :descendant, status: "finished") }

    it "is left out of the emerged runs though it carries its parent's emergence" do
      expect(described_class.emerged).to contain_exactly(descendant.parent_run)
    end

    it "is left out of the transitioned runs" do
      descendant.update!(transition_epoch: 1_200)

      expect(described_class.transitioned).to contain_exactly(descendant.parent_run)
    end
  end

  describe "descendant validation" do
    let(:parent) { create(:run, :emerged, epochs: 1_000) }

    before { insert_snapshots(parent, [500, 1_000]) }

    def descendant(**attributes)
      build(:run, parent_run: parent, parent_epoch: 1_000, epochs: 2_000, epochs_done: 1_000, **attributes)
    end

    it "accepts a child that changes the parent's dynamics alone" do
      expect(descendant(params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.01, "radius" => 2))).to be_valid
    end

    it "accepts the parent's params and seed, the exact continuation" do
      expect(descendant(params: parent.params, seed: parent.seed)).to be_valid
    end

    %w[width height tape_len max_tape_len ops].each do |key|
      it "refuses a child that changes the parent's #{key}" do
        changed = key == "ops" ? "<>{}" : Lab::Schema.run_defaults.fetch(key) + 8
        child = descendant(params: Lab::Schema.run_defaults.merge(key => changed))

        expect(child.tap(&:valid?).errors[:params]).to be_present
      end
    end

    it "refuses a child whose experiment runs another substrate" do
      child = descendant(experiment: create(:experiment, substrate: "life"))

      expect(child.tap(&:valid?).errors[:params]).to be_present
    end

    it "refuses a parent epoch the parent stored no world at" do
      child = descendant(parent_epoch: 700)

      expect(child.tap(&:valid?).errors[:parent_epoch]).to be_present
    end

    it "refuses a parent epoch inside the baseline window, which the engine cannot descend from" do
      insert_snapshots(parent, [Lab::TransitionRule::BASELINE_EPOCHS])
      child = descendant(parent_epoch: Lab::TransitionRule::BASELINE_EPOCHS)

      expect(child.tap(&:valid?).errors[:parent_epoch]).to be_present
    end

    it "refuses a budget that does not run past the parent epoch" do
      expect(descendant(epochs: 1_000)).not_to be_valid
    end

    it "is enforced by the database for a parent without an epoch" do
      run = create(:run)

      expect { run.update!(parent_run: parent) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe ".descend_from" do
    let(:parent) { create(:run, :emerged, epochs: 20_000, emergence_epoch: 4_200) }
    let(:experiment) { create(:experiment, priority: 7) }
    let(:params) { parent.params.merge("mutation_rate" => 0.0) }

    before { insert_snapshots(parent, [10_000, 20_000]) }

    it "starts the child at the parent's latest stored world, for the budget on top of it" do
      child = described_class.descend_from(parent, params: params, seed: 9, budget: 5_000, experiment: experiment)

      expect(child).to have_attributes(parent_run: parent, parent_epoch: 20_000, epochs: 25_000,
                                       epochs_done: 20_000, seed: 9, params: params, status: "pending",
                                       priority: 7, experiment: experiment)
    end

    it "starts the child at an earlier stored world it is given" do
      child = described_class.descend_from(parent, params: params, seed: 9, budget: 5_000, experiment: experiment,
                                                   epoch: 10_000)

      expect(child).to have_attributes(parent_epoch: 10_000, epochs: 15_000, epochs_done: 10_000)
    end

    it "carries the parent's emergence and no transition" do
      child = described_class.descend_from(parent, params: params, seed: 9, budget: 5_000, experiment: experiment)

      expect(child).to have_attributes(emergence_epoch: 4_200, emergence_witness: parent.emergence_witness,
                                       transition_epoch: nil, transition_epoch_relative: nil)
    end

    it "refuses a child that changes the parent's structure" do
      expect do
        described_class.descend_from(parent, params: params.merge("width" => 64), seed: 9, budget: 5_000,
                                             experiment: experiment)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#colony_age_at" do
    it "counts from the emergence a descendant inherited from its parent" do
      child = build(:run, parent_epoch: 20_000, emergence_epoch: 4_200)

      expect(child.colony_age_at(21_000)).to eq(16_800)
    end

    it "is nothing for a run that never emerged" do
      expect(build(:run).colony_age_at(21_000)).to be_nil
    end
  end

  describe "#earlier_transition_epoch?" do
    it "never takes a crossing a descendant reports" do
      expect(build(:run, parent_run_id: 1, parent_epoch: 1_000)).not_to be_earlier_transition_epoch(1_200)
    end

    it "never takes a relative crossing a descendant reports" do
      expect(build(:run, parent_run_id: 1, parent_epoch: 1_000)).not_to be_earlier_transition_epoch_relative(1_200)
    end
  end
end
