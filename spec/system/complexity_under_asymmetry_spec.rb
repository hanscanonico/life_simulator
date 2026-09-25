# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The complexity-under-asymmetry finding", type: :system do
  let(:experiment) do
    create(:experiment, name: "Asymmetric execution", slug: "asymmetric-execution",
                        param_grid: Lab::SWEEPS.fetch("asymmetric_execution").fetch(:param_grid))
  end

  before do
    emerged("concat", instructions: ([10] * 10) + ([10] * 10), core: [0] * 20, lineages: ([30] * 10) + ([3] * 10))
    emerged("concat", instructions: ([10] * 10) + ([5] * 10), core: [0] * 20, lineages: ([30] * 10) + ([3] * 10))
    8.times { unemerged("concat") }
    10.times { unemerged("host") }

    visit finding_path("complexity-under-asymmetry")
  end

  it "states the barren host arm and the claim it leaves unevaluable" do
    expect(page).to have_no_text("No claim yet")
    expect(page).to have_css(".badge.badge-error", text: "no host arm held a replicator")
    expect(page).to have_text(
      "The one host arm is barren — host 128 (0 of 10) held no replicator at all, against 2 of 10 in " \
      "concat 128, the concat control at the same cap — so there is no complexity in it to read and the " \
      "refutation condition cannot be evaluated."
    )
    expect(page).to have_text("beside controls that held replicators it kept replication from arising at all")
    expect(page).to have_text("not refuted by a plateau")
    expect(page).to have_no_text("measured runs of the host arms keep rising")
  end

  it "tables how often life emerged, the barren arm against its control" do
    within("#complexity-arms-emergence") do
      expect(page).to have_css("tr", text: /concat 128\s+control\s+10\s+2\s+2 of 10/)
      expect(page).to have_css("tr", text: /host 128\s+barren\s+10\s+0\s+0 of 10/)
    end
    expect(page).to have_text("0 of 10 runs of the host arms emerged against 2 of 10")
  end

  it "reads the concat control under both rules as the reference" do
    statement = "Under the pre-registered rule 2 of the 2 emerged runs are unmeasured and no arm reads."

    within("#complexity-arms-verdict") { expect(page).to have_text(statement) }
    expect(page).to have_text(statement, count: 2)
    expect(page).to have_text("Read under the amended rule, concat 128 has 0 rising and 1 plateauing of " \
                              "2 measured runs and reads plateau.")
    expect(page).to have_css("#complexity-reading")
  end

  it "reads the secondary reading and the refutation condition as unevaluable" do
    expect(page).to have_text("The secondary reading is unreadable: host 128 has no measured emerged run")
    expect(page).to have_text("The condition cannot be evaluated: no host arm held a replicator")
  end

  def params_of(interaction) = { "interaction" => interaction, "max_tape_len" => 128 }

  def emerged(interaction, instructions:, core:, lineages:)
    run = create(:run, :emerged, experiment: experiment, params: params_of(interaction))
    instructions.each_with_index do |count, index|
      create(:sample, run: run, epoch: run.emergence_epoch + (index * 10),
                      values: { "dominant_instruction_count" => count, "conserved_core_bytes" => core[index],
                                "distinct_lineages" => lineages[index] })
    end
  end

  def unemerged(interaction)
    run = create(:run, experiment: experiment, params: params_of(interaction), status: "finished")
    create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })
  end
end
