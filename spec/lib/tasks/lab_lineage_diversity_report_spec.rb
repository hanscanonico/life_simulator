# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:lineage_diversity_report" do
  let!(:experiment) { lineage_diversity_experiment }

  before do
    lineage_run(experiment, radius: 1, effective: 3.0, seed: 7)
    lineage_run(experiment, radius: 1, effective: 1.0, seed: 8)
    lineage_run(experiment, radius: 0, status: "pending", seed: 9)
  end

  after { ENV.delete("FORMAT") }

  it "prints every run under its arm, labelled interim while runs are pending" do
    expect(invoke("lab:lineage_diversity_report"))
      .to start_with("interim reading")
      .and match(/^\s*radius\s+seed\s+run_id\s+status\s+emerged\s+class\s+last_decile_effective_count\s+emergence_epoch/)
      .and match(/radius 1\s+7\s+\d+\s+finished\s+true\s+polyphyletic\s+3\s+1000/)
      .and match(/well-mixed\s+9\s+\d+\s+pending\s+—\s+—\s+—\s+1000/)
  end

  it "prints the arm table and the verdict" do
    expect(invoke("lab:lineage_diversity_report"))
      .to match(/radius 1\s+2\s+2\s+2\s+2\s+1\s+0\s+1\s+0\s+1\s+read/)
      .and include("hypothesis neither shown nor refuted; no trend test: fewer than 2 read arms; unread: well-mixed")
  end

  context "with FORMAT=csv" do
    it "writes CSV" do
      ENV["FORMAT"] = "csv"

      expect(CSV.parse(invoke("lab:lineage_diversity_report")))
        .to include(Lab::LineageDiversityReading::RUN_COLUMNS, Lab::LineageDiversityReading::ARM_COLUMNS)
    end
  end

  context "with no lineage-diversity sweep seeded" do
    it "says so" do
      experiment.update!(slug: "another-sweep")

      expect { invoke("lab:lineage_diversity_report") }.to raise_error(/not seeded/)
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
