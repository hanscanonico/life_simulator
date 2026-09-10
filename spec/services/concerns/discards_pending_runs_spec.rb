# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscardsPendingRuns do
  subject(:discarder) do
    Class.new do
      include DiscardsPendingRuns

      def call(runs) = discard!(runs)
    end.new
  end

  it "deletes the runs it is handed and returns their ids in order" do
    runs = create_list(:run, 2)

    expect(discarder.call(runs.reverse)).to eq(runs.map(&:id).sort)
    expect(Run.count).to eq(0)
  end

  context "with a run a runner claimed after the batch was read" do
    it "refuses the batch" do
      run = create(:run)
      Run.where(id: run.id).update_all(status: "claimed")

      expect { discarder.call([run]) }.to raise_error(ArgumentError, /#{run.id} are not pending/)
      expect(Run.exists?(run.id)).to be(true)
    end
  end

  context "with a run that carries a sample" do
    it "refuses the batch" do
      run = create(:run)
      create(:sample, run: run)

      expect { discarder.call([run]) }.to raise_error(ArgumentError, /carry samples or snapshots/)
      expect(Run.exists?(run.id)).to be(true)
    end
  end
end
