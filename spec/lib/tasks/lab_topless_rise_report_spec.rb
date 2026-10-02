# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:topless_rise_report" do
  after { ENV.delete("FORMAT") }

  context "with the sweep seeded from the meta-stack children of one parent" do
    before do
      topless_rise_parents
      Experiments::DescendantSweepBuilderService.call(topless_rise_experiment)
    end

    it "prints every child, the tests and their other readings, labelled interim while they run" do
      expect(invoke("lab:topless_rise_report"))
        .to start_with("topless-rise reading, interim")
        .and match(/^\s*run_id\s+parent\s+seed\s+treatment\s+status\s+deep_parent/)
        .and match(/H-rise\s+rise\s+none\s+0\s+0\s+0\s+0\s+—\s+no measured pairs/)
        .and match(/H-rise-paid, extinct kept\s+rise\s+capped/)
        .and match(/H-rise, deep subgroup\s+rise\s+none/)
    end

    context "with FORMAT=csv" do
      it "writes CSV" do
        ENV["FORMAT"] = "csv"

        expect(CSV.parse(invoke("lab:topless_rise_report"))).to include(Lab::ToplessRiseReading::CHILD_COLUMNS)
      end
    end
  end

  context "with no topless-rise sweep seeded" do
    it "says so" do
      expect { invoke("lab:topless_rise_report") }.to raise_error(/not seeded/)
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
