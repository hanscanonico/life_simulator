# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:transition_report" do
  let(:experiment) { create(:experiment, slug: "mutation-rate", param_grid: { "mutation_rate" => [0.0, 0.001] }) }

  let!(:run) do
    created = create(:run, experiment: experiment, status: "finished", transition_epoch: 100,
                           params: Lab::Schema.run_defaults.merge("mutation_rate" => 0.001))
    create(:sample, run: created, epoch: 100,
                    values: { "compress_ratio" => 0.5, "distinct_tapes" => 200, "top_share" => 0.3,
                              "replicator_count" => 3, "entropy_bits" => 2.0, "copy_rate" => 0.004 })
    created
  end

  it "prints the run header" do
    expect(invoke("lab:transition_report", "mutation-rate"))
      .to match(/run_id\s+seed\s+mutation_rate\s+transition_epoch/)
  end

  it "prints one line per sampled run" do
    expect(invoke("lab:transition_report", "mutation-rate"))
      .to match(
        /^\s*#{run.id}\s+#{run.seed}\s+0\.001\s+100\s+100\s+100\s+census\s+2\s+100\s+3\s+100\s+100\s+0\.004\s+100\s/
      )
  end

  it "prints the arm summary" do
    expect(invoke("lab:transition_report", "mutation-rate")).to match(/arm\s+n\s+flagged\s+replicators\s+both/)
  end

  context "with FORMAT=csv" do
    it "writes the report as CSV" do
      csv = with_env("FORMAT", "csv") { invoke("lab:transition_report", "mutation-rate") }

      expect(CSV.parse(csv).first.first(2)).to eq(%w[run_id seed])
    end
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:transition_report", "colour") }.to raise_error(/Unknown experiment "colour"/)
  end

  def with_env(name, value)
    original = ENV.fetch(name, nil)
    ENV[name] = value
    yield
  ensure
    ENV[name] = original
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
