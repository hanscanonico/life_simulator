# frozen_string_literal: true

# One descendant child of a logic-ladder sweep, read as the logic entry reads it: its own
# samples past the settling window under the from-emerged complexity rule
# (Lab::DescendantReading::Child), every own sample under the held-out entry's extinction and
# settled-relapse rules (Lab::FromEmergedHeldout::Child) and the logic readings
# (Lab::LogicReading::Child), and the descriptive estimate of the share of income its paid
# rungs bring. Experiments::LogicReadingService and Experiments::MetaStackReadingService read
# their children through it, so the two sweeps are read by one set of rules.
#
# The host names the sample keys it pulls (`SAMPLE_KEYS`) and those it reads as last-decile
# medians (`DESCRIPTIVE_KEYS`) as constants of its own.
module ReadsLogicChildren
  private

  # The parts of a child's row: `reading`, `heldout`, `logic` and `income_share`.
  def logic_child_reading(run)
    samples = own_samples(run)
    settled = samples.select { |epoch, _| epoch > run.parent_epoch + Lab::LogicReading::SETTLING_WINDOW }
    reading = Lab::DescendantReading::Child.read(settled, parent_epoch: run.parent_epoch,
                                                          descriptive: self.class::DESCRIPTIVE_KEYS)
    { reading: reading,
      heldout: Lab::FromEmergedHeldout::Child.read(samples, parent_epoch: run.parent_epoch,
                                                            last_share: reading.last_share),
      logic: Lab::LogicReading::Child.read(samples, parent_epoch: run.parent_epoch),
      income_share: income_share(run.params, reading) }
  end

  # Task income per cell and epoch, `task_reward × Σ units × share / task_every` over the
  # paid rungs' last-decile median shares — those at or above the run's `task_floor` —
  # against the influx: an estimate, since it ignores the stock cap a lump can hit. Nil
  # where a share is missing.
  def income_share(params, reading)
    shares = Lab::LogicReading::TASKS.map { |task| reading.last_median(Lab::LogicReading.share_key(task)) }
    return nil if shares.any?(&:nil?)

    units = shares.zip(paid_units(params.fetch("task_floor", Lab::LogicReading::TASKS.first)))
                  .sum { |share, unit| Rational(share.to_s) * unit }
    income = units * params.fetch("task_reward", 0).to_i / params.fetch("task_every", 1).to_i
    total = income + params.fetch("energy_influx", 0).to_i
    total.zero? ? nil : (income / total).to_f
  end

  # Each rung's units, 0 below the floor.
  def paid_units(floor)
    floor_index = Lab::LogicReading::TASKS.index(floor) || 0
    task_units.each_with_index.map { |units, index| index >= floor_index ? units : 0 }
  end

  def task_units
    @task_units ||= begin
      ladder = Lab::Schema.tasks.fetch("logic").fetch("ladder").to_h { |task| [task.fetch("name"), task.fetch("units")] }
      Lab::LogicReading::TASKS.map { |task| ladder.fetch(task) }
    end
  end

  def descendant_runs(experiment)
    experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed, :id)
              .select(:id, :parent_run_id, :parent_epoch, :seed, :params, :status).to_a
  end

  def own_samples(run)
    run.samples.where("epoch > ?", run.parent_epoch).order(:epoch).pluck(:epoch, observed_values)
  end

  def observed_values
    keys = self.class::SAMPLE_KEYS
    @observed_values ||= Arel.sql(ActiveRecord::Base.sanitize_sql_array(
      ["jsonb_build_object(#{(['?, samples.values -> ?'] * keys.size).join(', ')})",
       *keys.flat_map { |key| [key, key] }]
    ))
  end
end
