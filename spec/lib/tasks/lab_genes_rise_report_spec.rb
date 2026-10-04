# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:genes_rise_report" do
  after { ENV.delete("FORMAT") }
  after { ENV.delete("MINIMA") }

  context "with the sweep seeded from one reach-cap128 parent" do
    let(:experiment) { genes_rise_experiment }

    before do
      genes_rise_parents
      Experiments::DescendantSweepBuilderService.call(experiment)
    end

    it "prints every child and the five tests with their extinct-kept readings, labelled interim while they run" do
      expect(invoke("lab:genes_rise_report"))
        .to start_with("genes-rise reading, interim")
        .and include("H-driven awaits the offline minimum")
        .and match(/^\s*run_id\s+parent\s+seed\s+treatment\s+status\s+settled_relapse_epoch/)
        .and match(/H-rise\s+count\s+drift\s+0\s+0\s+0\s+0\s+—\s+no measured pairs/)
        .and match(/H-room, extinct kept\s+count\s+capped/)
        .and match(/H-shadow\s+count\s+shadow/)
    end

    context "with MINIMA naming the offline minimum's CSV" do
      it "reads H-driven on it" do
        rows = experiment.runs.order(:id).map { |run| "#{run.id},90,150" }
        file = Tempfile.new(%w[minima .csv]).tap { |csv| csv.write(["run_id,fifth_minimum,last_minimum", *rows, ""].join("\n")) }
        file.close
        experiment.runs.each { |run| genes_rise_sample(run) }
        ENV["MINIMA"] = file.path

        expect(invoke("lab:genes_rise_report")).not_to include("awaits")
        expect(invoke("lab:genes_rise_report")).to match(/H-driven\s+count\s+drift\s+1\s+0\s+0\s+1/)
      end
    end

    context "with FORMAT=csv" do
      it "writes CSV" do
        ENV["FORMAT"] = "csv"

        expect(CSV.parse(invoke("lab:genes_rise_report"))).to include(Lab::GenesRiseReading::CHILD_COLUMNS)
      end
    end
  end

  context "with no genes-rise sweep seeded" do
    it "says so" do
      expect { invoke("lab:genes_rise_report") }.to raise_error(/not seeded/)
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
