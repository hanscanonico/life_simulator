# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The complexity-under-contest finding", type: :system do
  let(:experiment) do
    create(:experiment, name: "Host–parasite economy", slug: "host-parasite",
                        param_grid: Lab::SWEEPS.fetch("host_parasite").fetch(:param_grid))
  end
  let(:off) { { "energy_influx" => 0, "steal_amount" => 0 } }
  let(:stealing) { { "energy_influx" => 2_048, "steal_amount" => 1_024 } }
  let(:poorest) { { "energy_influx" => 512, "steal_amount" => 0 } }

  before do
    emerged(off, instructions: ([10] * 10) + ([5] * 10), core: [0] * 20)
    emerged(off, instructions: ([10] * 10) + ([5] * 10), core: [40] * 20)
    8.times { unemerged(off) }
    emerged(stealing, instructions: ([10] * 10) + ([30] * 10), core: [0] * 20, steal_rate: 0.3)
    emerged(stealing, instructions: ([10] * 10) + ([5] * 10), core: [0] * 20, steal_rate: 0.3)
    10.times { unemerged(poorest) }

    visit finding_path("complexity-under-contest")
  end

  it "states the claim the arms read" do
    expect(page).to have_no_text("No claim yet")
    expect(page).to have_text(
      "Complexity kept rising in 1 of the 2 priced arms — 1024×2048 128, on 1 of its 2 measured runs; " \
      "1 held no replicator at all, while the economy-off control reads neither."
    )
    expect(page).to have_css(".badge.badge-warning", text: "keeps rising in 1 of 2 arms")
  end

  it "tables how often life emerged, the barren arm included" do
    within("#complexity-arms-emergence") do
      expect(page).to have_css("tr", text: /0 128\s+control\s+10\s+2\s+2 of 10/)
      expect(page).to have_css("tr", text: /0×512 128\s+barren\s+10\s+0\s+0 of 10/)
    end
    expect(page).to have_text("0×512 128 (0 of 10) emerged in none of its runs and reads barren")
  end

  it "states the pre-registered rule's result beside the amended claim and its arm table" do
    statement = "Under the pre-registered rule 3 of the 4 emerged runs are unmeasured and no arm reads."

    within("#complexity-arms-verdict") { expect(page).to have_text(statement) }
    expect(page).to have_css("#complexity-reading")
    expect(page).to have_text(statement, count: 2)
    expect(page).to have_text("The barren arms read barren under either rule")
  end

  it "reads the theft the steal arm evolved" do
    expect(page).to have_text("Theft evolved in the one steal arm, peak steal_rate 0.30.")
  end

  it "checks the claim against the refutation condition" do
    expect(page).to have_text("No economy-off control plateaus, so there is no control plateau for a priced arm " \
                              "to match and the condition is not met on these runs.")
  end

  def params_of(economy) = economy.merge("max_tape_len" => 128)

  def emerged(economy, instructions:, core:, steal_rate: nil)
    run = create(:run, :emerged, experiment: experiment, params: params_of(economy))
    instructions.each_with_index do |count, index|
      create(:sample, run: run, epoch: run.emergence_epoch + (index * 10),
                      values: { "dominant_instruction_count" => count, "conserved_core_bytes" => core[index],
                                "steal_rate" => steal_rate }.compact)
    end
  end

  def unemerged(economy)
    run = create(:run, experiment: experiment, params: params_of(economy), status: "finished")
    create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.9 })
  end
end
