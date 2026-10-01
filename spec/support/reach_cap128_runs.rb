# frozen_string_literal: true

# Runs of the reach-cap128 sweep and of its host-parasite control, with the stored worlds
# the readings pass reads, for the specs of its reading, its page section and its report.
module ReachCap128Runs
  def reach_cap128_experiment
    create(:experiment, name: "Reach with room to grow", slug: "reach-cap128",
                        **Lab::SWEEPS.fetch("reach_cap128").slice(:param_grid, :epochs))
  end

  def host_parasite_control_experiment
    create(:experiment, name: "Host–parasite economy", slug: "host-parasite")
  end

  # A run of `experiment` over 2 000 epochs whose stored worlds at 0, 1 000 and 2 000 read
  # `shares` in that order. `crossing` is its confirmed emergence epoch, nil for none;
  # `unread` adds a world the readings pass has not read yet. `params` are merged over the
  # sweep's own.
  def reach_run(experiment, crossing: nil, shares: [0.0, 0.0, 0.0], status: "finished", unread: false,
                params: {}, seed: nil)
    run = create(:run, experiment: experiment, status: status, epochs: 2_000, emergence_epoch: crossing,
                       seed: seed || generate(:reach_cap128_seed), params: reach_params.merge(params))
    shares.each_with_index do |share, index|
      create(:snapshot, run: run, epoch: index * 1_000)
      create(:snapshot_reading, run: run, epoch: index * 1_000, source_epoch: index * 1_000,
                                values: { "replicator_share" => share, "dominant_self_replicates" => share >= 0.5 })
    end
    create(:snapshot, run: run, epoch: 500) if unread
    run
  end

  # A run of the cap-128 control: radius 1, the economy off.
  def control_run(experiment, **)
    reach_run(experiment, params: { "radius" => 1, "lineage_rule" => "aligned" }, **)
  end

  def reach_params
    Lab::Schema.run_defaults.merge(Lab::SWEEPS.fetch("reach_cap128")[:param_grid].transform_values(&:first))
  end

  # An arm of `counted` counted runs, `emerged` of them emerged.
  def reach_arm(label, emerged, counted)
    rows = Array.new(counted) do |index|
      Experiments::ReachCap128ReadingService::RunRow.new(
        run_id: index, arm: label, seed: index, status: "finished", emergence_epoch: nil, measured: true,
        emerged: index < emerged, terminal_share: nil, dominant_raw_len: nil, dominant_instruction_count: nil,
        dominant_self_replicates: nil
      )
    end
    Lab::ReachCap128Reading::Arm.new(label: label, rows: rows)
  end
end

FactoryBot.define { sequence(:reach_cap128_seed) { |n| n } }

RSpec.configure { |config| config.include ReachCap128Runs }
