# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lab:transition_audit" do
  let!(:experiment) { create(:experiment, slug: "bff-control") }
  let(:run) { create(:run, experiment: experiment, status: "finished", transition_epoch: 400) }

  before do
    create(:sample, run: run, epoch: 400, values: { "compress_ratio" => 0.143, "op_density" => 1.0 })
  end

  it "prints the run header" do
    expect(invoke("lab:transition_audit"))
      .to match(/run_id\s+experiment\s+transition_epoch\s+dense_epoch\s+op_density/)
  end

  it "names the run the guard would no longer accept, without changing it" do
    output = invoke("lab:transition_audit", "bff-control")

    expect(output).to match(/^\s*#{run.id}\s+bff-control\s+400\s+400\s+1\.0\s+0\.143\s+—\s+—$/)
    expect(output).to include("no stored transition_epoch was changed")
    expect(run.reload.transition_epoch).to eq(400)
  end

  it "refuses an experiment it does not know" do
    expect { invoke("lab:transition_audit", "colour") }.to raise_error(/Unknown experiment "colour"/)
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
