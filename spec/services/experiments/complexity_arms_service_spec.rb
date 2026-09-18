# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiments::ComplexityArmsService do
  subject(:arms) { described_class.call(experiment: experiment) }

  let(:experiment) do
    create(:experiment, param_grid: { "economy" => [{ "energy_influx" => 0, "steal_amount" => 0 },
                                                    { "energy_influx" => 512, "steal_amount" => 1_024 }] })
  end

  describe "the reading of one run" do
    it "compares the last decile of its post-emergence samples against the first" do
      emerged(instructions: ([10] * 10) + ([30] * 10))

      expect(arms.sole).to have_attributes(measured_count: 1, rising_count: 1, plateau_count: 0)
    end

    it "reads a rise short of a fifth as no rise" do
      emerged(instructions: ([10] * 10) + ([11] * 10))

      expect(arms.sole).to have_attributes(rising_count: 0, plateau_count: 1)
    end

    it "reads a rise of exactly a fifth as a rise" do
      emerged(instructions: ([10] * 10) + ([12] * 10))

      expect(arms.sole).to have_attributes(rising_count: 1, plateau_count: 0)
    end

    it "refuses a rise the conserved core paid for" do
      emerged(instructions: ([10] * 10) + ([30] * 10), core: ([40] * 10) + ([20] * 10))

      expect(arms.sole).to have_attributes(measured_count: 1, rising_count: 0)
    end

    it "keeps a rise the conserved core held through" do
      emerged(instructions: ([10] * 10) + ([30] * 10), core: ([40] * 10) + ([40] * 10))

      expect(arms.sole.rising_count).to eq(1)
    end

    it "ignores the samples before the crossing" do
      run = emerged(instructions: [100] * 20, emergence_epoch: 2_100)
      20.times { |index| create(:sample, run: run, epoch: index * 10, values: { "dominant_instruction_count" => 1 }) }

      expect(arms.sole.instructions).to have_attributes(first: 100, last: 100)
      expect(arms.sole.rising_count).to eq(0)
    end

    it "leaves a run with a single reading unmeasured" do
      emerged(instructions: [10] * 20)
      emerged(instructions: [10])

      expect(arms.sole).to have_attributes(emerged_count: 2, measured_count: 1)
    end

    it "leaves a run whose samples carry no instruction count unmeasured" do
      emerged(instructions: [10] * 20)
      run = create(:run, :emerged, experiment: experiment, params: control_params)
      create(:sample, run: run, epoch: 100, values: { "compress_ratio" => 0.4 })

      expect(arms.sole).to have_attributes(emerged_count: 2, measured_count: 1)
    end

    it "leaves a run with no conserved core over the span unmeasured" do
      emerged(instructions: [10] * 20)
      emerged(instructions: ([10] * 10) + ([30] * 10), core: [])

      expect(arms.sole).to have_attributes(emerged_count: 2, measured_count: 1, rising_count: 0)
    end

    it "leaves a run whose instruction count is zero throughout unmeasured" do
      emerged(instructions: [10] * 20)
      emerged(instructions: [0] * 20)

      expect(arms.sole).to have_attributes(emerged_count: 2, measured_count: 1, plateau_count: 1)
    end
  end

  describe "the reading of an arm" do
    it "needs two measured runs before it reads at all" do
      emerged(instructions: ([10] * 10) + ([30] * 10))

      expect(arms.sole).to have_attributes(reading: :unread, readable?: false)
    end

    it "keeps rising where half its measured runs do" do
      emerged(instructions: ([10] * 10) + ([30] * 10))
      emerged(instructions: ([10] * 10) + ([5] * 10))

      expect(arms.sole).to have_attributes(reading: :keeps_rising, rising_count: 1, measured_count: 2)
    end

    it "reads an arm split between a rising run and a plateauing one as mixed" do
      emerged(instructions: ([10] * 10) + ([30] * 10))
      emerged(instructions: ([10] * 10) + ([10] * 10))

      expect(arms.sole).to have_attributes(reading: :mixed, rising_count: 1, plateau_count: 1)
    end

    it "plateaus where half its measured runs sit within a tenth of where they started" do
      2.times { emerged(instructions: ([10] * 10) + ([10] * 10)) }

      expect(arms.sole.reading).to eq(:plateau)
    end

    it "reads an arm clearing neither bar as neither, not as mixed" do
      emerged(instructions: ([10] * 10) + ([30] * 10))
      2.times { emerged(instructions: ([10] * 10) + ([5] * 10)) }

      expect(arms.sole).to have_attributes(reading: :neither, rising_count: 1, plateau_count: 0)
    end

    it "reads a blank block of ten as an arm holding no replicator to read" do
      10.times { create(:run, experiment: experiment, status: "finished", params: control_params) }
      Run.find_each { |run| create(:sample, run: run, values: { "compress_ratio" => 0.9 }) }

      expect(arms.sole).to have_attributes(reading: :barren, emerged_count: 0, terminal_count: 10)
    end

    it "publishes the medians its reading is taken on, compressed length beside them" do
      emerged(instructions: ([10] * 10) + ([30] * 10), core: [40] * 20, compressed: ([75] * 10) + ([139] * 10))

      expect(arms.sole.instructions).to have_attributes(first: 10, last: 30)
      expect(arms.sole.core).to have_attributes(first: 40, last: 40)
      expect(arms.sole.compressed).to have_attributes(first: 75, last: 139)
    end
  end

  describe "the theft null" do
    let(:thief_params) { Lab::Schema.run_defaults.merge("energy_influx" => 512, "steal_amount" => 1_024) }

    it "reads an arm whose steal rate never left zero as theft that never evolved" do
      emerged(instructions: [10] * 20, steal_rate: [0.0] * 20, params: thief_params)

      expect(arms.last).to have_attributes(theft: :never_evolved, peak_steal_rate: 0.0)
    end

    it "reads an arm whose tapes stole as theft that evolved" do
      emerged(instructions: [10] * 20, steal_rate: ([0.0] * 19) + [0.25], params: thief_params)

      expect(arms.last).to have_attributes(theft: :evolved, peak_steal_rate: 0.25)
    end

    it "reads an arm no steal rate was ever sampled on as theft unmeasured" do
      emerged(instructions: [10] * 20, params: thief_params)

      expect(arms.last).to have_attributes(theft: :unmeasured, peak_steal_rate: nil)
    end

    it "says nothing about theft in an arm whose steal op is off" do
      emerged(instructions: [10] * 20)

      expect(arms.sole.theft).to eq(:no_steal_op)
    end
  end

  it "names an arm the way the sweep's phase diagram does" do
    emerged(instructions: [10] * 20)

    expect(arms.sole.label).to eq("0")
  end

  it "leaves an arm nothing has been sampled from out of the reading" do
    create(:run, experiment: experiment, params: control_params)

    expect(arms).to be_empty
  end

  def control_params = Lab::Schema.run_defaults.merge("energy_influx" => 0, "steal_amount" => 0)

  # A flat conserved core by default: the reading needs one over the same span, and a run
  # deliberately without it passes `core: []`.
  def emerged(instructions:, core: [40] * instructions.size, compressed: nil, steal_rate: nil,
              emergence_epoch: 100, params: control_params)
    run = create(:run, :emerged, experiment: experiment, params: params,
                                 transition_epoch: emergence_epoch, emergence_epoch: emergence_epoch)
    instructions.each_with_index do |count, index|
      create(:sample, run: run, epoch: emergence_epoch + (index * 10),
                      values: { "dominant_instruction_count" => count,
                                "conserved_core_bytes" => core&.at(index),
                                "dominant_compressed_len" => compressed&.at(index),
                                "steal_rate" => steal_rate&.at(index) }.compact)
    end
    run
  end
end
