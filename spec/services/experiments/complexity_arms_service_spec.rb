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

    it "reads a run whose conserved core is zero over the whole span as measured" do
      emerged(instructions: ([10] * 10) + ([30] * 10), core: [0] * 20)

      expect(arms.sole).to have_attributes(measured_count: 1, rising_count: 1)
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

    it "counts the measured runs the pre-registered rule would have dropped" do
      emerged(instructions: ([10] * 10) + ([30] * 10), core: [0] * 20)
      emerged(instructions: ([10] * 10) + ([30] * 10))

      expect(arms.sole).to have_attributes(measured_count: 2, pre_registered_unmeasured_count: 1)
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

    it "carries the late-run lineage count the secondary reading is taken on" do
      emerged(instructions: [10] * 20, lineages: ([900] * 10) + ([120] * 10))

      expect(arms.sole.lineages).to have_attributes(first: 900, last: 120)
    end

    it "leaves the lineage span blank on an arm no lineage census was sampled in" do
      emerged(instructions: [10] * 20)

      expect(arms.sole.lineages).to be_nil
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

  # The host-parasite sweep is 1 260 runs of hundreds of samples each; a corpus where every
  # one of them emerged is the one this reading holds the most of at once (issues #226, #236).
  describe "reading a sweep where every run emerged" do
    let(:runs) { 200 }
    let(:samples_per_run) { 200 }

    before do
      insert_sweep(experiment, runs: runs, samples_per_run: samples_per_run, emergence_epoch: 100,
                               params: control_params) do |index|
        { "dominant_instruction_count" => 10 + index, "conserved_core_bytes" => 40 }
      end
    end

    # The spans are reduced in the database — four rows a run, never a sample — beside the
    # single experiment-wide aggregate the peak steal rate is read with.
    it "reads the post-crossing spans in one statement, holding no sample in Ruby" do
      reads = value_reads_during { arms.map(&:cells) }

      expect(reads.size).to eq(2)
      expect(reads.max).to be <= runs * described_class::SERIES.size
    end
  end

  # The spans moved from Ruby into one SQL statement (issue #236). Every value below was
  # worked by hand from the rule as the Ruby reading applied it — nulls and strings drop out
  # of their own series, a float reading truncates, the decile is ceil(n / 10) and its
  # median the lower middle — and checked against that Ruby reading before it was retired.
  describe "the reading of a mixed sweep, pinned" do
    let(:experiment) do
      create(:experiment, param_grid: { "economy" => [{ "energy_influx" => 0, "steal_amount" => 0 },
                                                      { "energy_influx" => 512, "steal_amount" => 1_024 },
                                                      { "energy_influx" => 2_048, "steal_amount" => 0 }] })
    end
    let(:thief_params) { Lab::Schema.run_defaults.merge("energy_influx" => 512, "steal_amount" => 1_024) }
    let(:blank_params) { Lab::Schema.run_defaults.merge("energy_influx" => 2_048, "steal_amount" => 0) }

    before do
      rising_through_noise
      plateau_on_a_zero_core
      emerged_run(control_params, [{ "dominant_instruction_count" => 10, "conserved_core_bytes" => 40 }])
      zero_start = [0] + ([5] * 8) + [7]
      emerged_run(control_params, zero_start.map { |count| { "dominant_instruction_count" => count, "conserved_core_bytes" => 40 } })
      thieves
      10.times { sampled_run(blank_params, { "dominant_instruction_count" => 5 }) }
    end

    it "reads every arm as the Ruby reading did" do
      expect(arms.map(&:cells)).to eq(
        [["0", 4, 2, 1, 10, 19, 0, 0, 100, 100, 5, 5, 1, 1, nil, nil, "mixed"],
         ["512×1024", 2, 2, 0, 8, 8, 40, 40, nil, nil, nil, nil, 1, 1, 0.5, "evolved", "mixed"],
         ["2048×0", 0, 0, 0, nil, nil, nil, nil, nil, nil, nil, nil, 0, 0, nil, nil, "barren"]]
      )
    end

    it "reads each run's spans as the Ruby reading did" do
      readings = arms.first.readings.map { |reading| reading.to_h.transform_values { |span| span&.to_h } }

      expect(readings).to eq(
        [{ instructions: { first: 10, last: 19 }, core: { first: 40, last: 40 },
           compressed: { first: 100, last: 100 }, lineages: nil },
         { instructions: { first: 20, last: 21 }, core: { first: 0, last: 0 }, compressed: nil,
           lineages: { first: 5, last: 5 } },
         { instructions: nil, core: nil, compressed: nil, lineages: nil },
         { instructions: { first: 0, last: 7 }, core: { first: 40, last: 40 }, compressed: nil, lineages: nil }]
      )
    end

    # Thirteen numeric instruction counts once a null, a string and the samples before the
    # crossing drop out, so an even decile of two: 10 first, 19 last, a rise. The float
    # reading 12.7 counts as 12, and the core's one null leaves it fourteen readings long.
    def rising_through_noise
      counts = [10, nil, 14, "12", 11, 13, 12, 15, 16, 12.7, 18, 20, 17, 22, 19]
      run = emerged_run(control_params, counts.each_with_index.map do |count, index|
        { "dominant_instruction_count" => count, "conserved_core_bytes" => index == 5 ? nil : 40,
          "dominant_compressed_len" => 100 }
      end)
      3.times { |index| create(:sample, run: run, epoch: index * 10, values: { "dominant_instruction_count" => 900 }) }
    end

    # Twenty-five readings, an odd decile of three: 20 first, 21 last, within a tenth. Its
    # core reads zero bytes throughout, which the amended rule measures and the
    # pre-registered one would have dropped.
    def plateau_on_a_zero_core
      counts = [30, 10, 20] + ([20] * 19) + [21, 19, 40]
      emerged_run(control_params, counts.map do |count|
        { "dominant_instruction_count" => count, "conserved_core_bytes" => 0, "distinct_lineages" => 5 }
      end)
    end

    # The peak steal rate is the arm's, over runs that never emerged too, and a steal rate
    # stored as a string is no reading, however high it reads.
    def thieves
      emerged_run(thief_params, Array.new(20) do |index|
        { "dominant_instruction_count" => index < 10 ? 10 : 13, "conserved_core_bytes" => 40,
          "steal_rate" => { 3 => "0.9", 7 => 0.25 }.fetch(index, 0.1) }
      end)
      emerged_run(thief_params, Array.new(20) do
        { "dominant_instruction_count" => 8, "conserved_core_bytes" => 40, "steal_rate" => 0.0 }
      end)
      run = sampled_run(thief_params, { "steal_rate" => 0.5 })
      create(:sample, run: run, epoch: 200, values: { "steal_rate" => nil })
    end

    def emerged_run(params, samples)
      run = create(:run, :emerged, experiment: experiment, params: params, transition_epoch: 100, emergence_epoch: 100)
      samples.each_with_index { |values, index| create(:sample, run: run, epoch: 100 + (index * 10), values: values) }
      run
    end

    def sampled_run(params, values)
      run = create(:run, experiment: experiment, status: "finished", params: params)
      create(:sample, run: run, epoch: 100, values: values)
      run
    end
  end

  def control_params = Lab::Schema.run_defaults.merge("energy_influx" => 0, "steal_amount" => 0)

  # A flat conserved core by default: the reading needs one over the same span, and a run
  # deliberately without it passes `core: []`.
  def emerged(instructions:, core: [40] * instructions.size, compressed: nil, steal_rate: nil,
              lineages: nil, emergence_epoch: 100, params: control_params)
    run = create(:run, :emerged, experiment: experiment, params: params,
                                 transition_epoch: emergence_epoch, emergence_epoch: emergence_epoch)
    instructions.each_with_index do |count, index|
      create(:sample, run: run, epoch: emergence_epoch + (index * 10),
                      values: { "dominant_instruction_count" => count,
                                "conserved_core_bytes" => core&.at(index),
                                "dominant_compressed_len" => compressed&.at(index),
                                "distinct_lineages" => lineages&.at(index),
                                "steal_rate" => steal_rate&.at(index) }.compact)
    end
    run
  end
end
