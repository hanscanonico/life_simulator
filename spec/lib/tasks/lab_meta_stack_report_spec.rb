# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:meta_stack_report" do
  after { ENV.delete("FORMAT") }

  context "with the sweep and its twins seeded from one parent" do
    before do
      metabolism_parent
      Experiments::DescendantSweepBuilderService.call(logic_experiment)
      Experiments::DescendantSweepBuilderService.call(meta_stack_experiment)
    end

    it "prints every child, the tests and their sensitivity readings, labelled interim while they run" do
      expect(invoke("lab:meta_stack_report"))
        .to start_with("meta-stack reading, interim")
        .and match(/^\s*run_id\s+parent\s+seed\s+treatment\s+status\s+settled_relapse_epoch/)
        .and match(/H-decouple\s+meta-inplace\s+logic-full\s+0\s+0\s+0\s+0\s+—\s+no measured pairs/)
        .and match(/H-deep-Ms, extinct kept\s+meta-stack\s+logic-none/)
        .and match(/H-stack, unpiloted parents\s+meta-stack\s+meta-inplace/)
    end

    context "with FORMAT=csv" do
      it "writes CSV" do
        ENV["FORMAT"] = "csv"

        expect(CSV.parse(invoke("lab:meta_stack_report"))).to include(Lab::MetaStackReading::CHILD_COLUMNS)
      end
    end
  end

  context "with no meta-stack sweep seeded" do
    it "says so" do
      expect { invoke("lab:meta_stack_report") }.to raise_error(/not seeded/)
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
