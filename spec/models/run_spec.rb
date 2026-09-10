# frozen_string_literal: true

require "rails_helper"

RSpec.describe Run, type: :model do
  subject(:run) { build(:run) }

  it { is_expected.to belong_to(:experiment) }
  it { is_expected.to have_many(:samples).dependent(:destroy) }
  it { is_expected.to have_many(:snapshots).dependent(:destroy) }
  it { is_expected.to validate_numericality_of(:epochs).only_integer.is_greater_than(0) }

  describe "indexes" do
    let(:indexes) { described_class.connection.indexes(described_class.table_name) }

    it "indexes heartbeat_at for the status page's live runners" do
      expect(indexes.map(&:columns)).to include(["heartbeat_at"])
    end

    it "indexes finished_at for the terminal runs the pruner walks" do
      index = indexes.find { |i| i.name == "index_runs_on_finished_at_terminal" }

      expect(index).to have_attributes(columns: ["finished_at"], where: a_string_including("finished"))
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

  describe "#terminal?" do
    it "is true for a failed run" do
      expect(build(:run, status: "failed")).to be_terminal
    end

    it "is false for a running run" do
      expect(build(:run, status: "running")).not_to be_terminal
    end
  end
end
