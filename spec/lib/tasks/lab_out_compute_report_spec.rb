# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:out_compute_report" do
  after { ENV.delete("FORMAT") }

  context "with the sweep seeded from one reach-cap128 parent" do
    before do
      out_compute_parents
      Experiments::DescendantSweepBuilderService.call(out_compute_experiment)
    end

    it "prints every child and the five tests with their sensitivity readings, labelled interim while they run" do
      expect(invoke("lab:out_compute_report"))
        .to start_with("out-compute reading, interim")
        .and match(/^\s*run_id\s+parent\s+seed\s+treatment\s+status\s+settled_relapse_epoch/)
        .and match(/H-endogenous\s+out-compute\s+none\s+0\s+0\s+0\s+0\s+—\s+no measured pairs/)
        .and match(/H-driven, extinct kept\s+out-compute\s+shadow/)
        .and match(/H-ratchet, unpiloted parents\s+out-compute\s+equal/)
        .and match(/H-repertoire\s+out-compute\s+none/)
    end

    context "with FORMAT=csv" do
      it "writes CSV" do
        ENV["FORMAT"] = "csv"

        expect(CSV.parse(invoke("lab:out_compute_report"))).to include(Lab::OutComputeReading::CHILD_COLUMNS)
      end
    end
  end

  context "with no out-compute sweep seeded" do
    it "says so" do
      expect { invoke("lab:out_compute_report") }.to raise_error(/not seeded/)
    end
  end

  def invoke(name, *args)
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    task = Rake::Task[name]
    task.reenable
    original = $stdout
    $stdout = StringIO.new
    task.invoke(*args)
    $stdout.string
  ensure
    $stdout = original
  end
end
