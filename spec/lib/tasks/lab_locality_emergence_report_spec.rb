# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:locality_emergence_report" do
  let!(:experiment) { locality_emergence_experiment }

  before do
    locality_run(experiment, radius: 4, share: 0.9, seed: 91)
    locality_run(experiment, radius: 1, seed: 92)
    locality_run(experiment, radius: 0, status: "pending", seed: 93)
  end

  after { ENV.delete("FORMAT") }

  it "prints every run under its arm, labelled interim while runs are pending" do
    expect(invoke("lab:locality_emergence_report"))
      .to start_with("interim reading")
      .and match(/^\s*radius\s+seed\s+run_id\s+status\s+emerged\s+emergence_epoch/)
      .and match(/radius 4\s+91\s+\d+\s+finished\s+true\s+1000/)
      .and match(/well-mixed\s+93\s+\d+\s+pending\s+—\s+—/)
  end

  it "prints the arm table and both hypotheses" do
    expect(invoke("lab:locality_emergence_report"))
      .to match(/radius 4\s+1\s+1\s+1\s+1/)
      .and include("H-peak not yet tested", "H-shape not yet tested")
  end

  context "with FORMAT=csv" do
    it "writes CSV" do
      ENV["FORMAT"] = "csv"

      expect(CSV.parse(invoke("lab:locality_emergence_report")))
        .to include(Lab::LocalityEmergenceReading::RUN_COLUMNS, Lab::LocalityEmergenceReading::ARM_COLUMNS)
    end
  end

  context "with no locality-emergence sweep seeded" do
    it "says so" do
      experiment.update!(slug: "another-sweep")

      expect { invoke("lab:locality_emergence_report") }.to raise_error(/not seeded/)
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
