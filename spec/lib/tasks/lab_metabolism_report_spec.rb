# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:metabolism_report" do
  after { ENV.delete("FORMAT") }

  context "with the sweep seeded from one parent" do
    before do
      metabolism_parent
      Experiments::DescendantSweepBuilderService.call(metabolism_experiment)
    end

    it "prints every child and the tests, labelled interim while they run" do
      expect(invoke("lab:metabolism_report"))
        .to start_with("metabolism reading, interim")
        .and match(/^\s*run_id\s+parent\s+seed\s+treatment\s+status\s+settled_relapse_epoch/)
        .and match(/H-ladder\s+reward\s+0\s+0\s+0\s+0\s+—\s+no measured pairs/)
    end

    context "with FORMAT=csv" do
      it "writes CSV" do
        ENV["FORMAT"] = "csv"

        expect(CSV.parse(invoke("lab:metabolism_report"))).to include(Lab::MetabolismReading::CHILD_COLUMNS)
      end
    end
  end

  context "with no metabolism sweep seeded" do
    it "says so" do
      expect { invoke("lab:metabolism_report") }.to raise_error(/not seeded/)
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
