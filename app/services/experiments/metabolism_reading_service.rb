# frozen_string_literal: true

module Experiments
  # The pre-registered reading of the metabolism sweep (`docs/design_record.md`, 2026-10-01,
  # "Metabolism: a second, labelled substrate that imports an objective"). Each child is
  # read over its own samples past the settling window, under the held-out reading's
  # extinction and settled-relapse rules (Lab::FromEmergedHeldout::Child) and the
  # from-emerged complexity rule (Lab::DescendantReading::Child), plus the task readings of
  # Lab::MetabolismReading::Child. Each reward child is paired with the no-reward child of
  # the same (parent, seed) and three sign tests are read over the pairs
  # (Lab::DescendantReading::Comparison), each re-read without the pairs of the parents the
  # design study piloted, as a sensitivity reading. It is interim until the parent pool is settled
  # and every child of every qualifying parent has finished.
  #
  # It reads stored samples, one child at a time, and changes nothing.
  class MetabolismReadingService
    include Callable

    SAMPLE_KEYS = [
      Lab::DescendantReading::SHARE_KEY, Lab::DescendantReading::REPLICATING_KEY,
      Lab::DescendantReading::COMPLEXITY_KEY, Lab::MetabolismReading::CAPABILITY_KEY,
      Lab::MetabolismReading::LOOP_CAPABILITY_KEY, Lab::MetabolismReading::DOMINANT_TASKS_KEY,
      *Lab::MetabolismReading::DESCRIPTIVE_KEYS
    ].uniq.freeze

    Treatment = Data.define(:key, :name)

    TREATMENTS = Lab::MetabolismReading::TREATMENT_NAMES.map { |key, name| Treatment.new(key: key, name: name) }.freeze

    # `reading` is the from-emerged rule's over the settled samples, `heldout` the held-out
    # entry's, `metabolism` the task readings; `income_share` the descriptive estimate of the
    # share of income that comes from tasks.
    ChildRow = Data.define(:run_id, :parent_id, :seed, :treatment, :status, :reading, :heldout, :metabolism,
                           :income_share) do
      delegate :capability, :climbed_loop?, :stepping_stone?, to: :metabolism

      def finished? = status == "finished"

      def settled_relapse? = !heldout.settled_relapse_epoch.nil?

      def extinct? = heldout.extinct == true

      def capability_measured?(key = Lab::MetabolismReading::CAPABILITY_KEY)
        heldout.read && !heldout.extinct && !capability(key).nil?
      end

      # The children H-complexity reads: neither extinct nor relapsed past the window, and
      # measured under the complexity rule.
      def complexity_survivor? = heldout.survivor? && reading.measured?

      def surviving_rise? = complexity_survivor? && reading.rises?

      def cells
        [run_id, parent_id, seed, treatment.name, status, heldout.settled_relapse_epoch, heldout.extinct,
         capability(Lab::MetabolismReading::CAPABILITY_KEY), capability(Lab::MetabolismReading::LOOP_CAPABILITY_KEY),
         reading.complexity, reading.first_instructions, reading.last_instructions,
         *metabolism.first_epochs.values_at(*Lab::MetabolismReading::TASKS), metabolism.dominant_tasks,
         *[Lab::MetabolismReading::DOMINANT_TASK_COUNT_KEY, Lab::MetabolismReading::LATENCY_KEY,
           Lab::MetabolismReading::SHARE_KEY].map { |key| reading.last_median(key) },
         income_share]
      end
    end

    HYPOTHESES = {
      "H-capability" => Lab::MetabolismReading::CAPABILITY_KEY,
      "H-ladder" => Lab::MetabolismReading::LOOP_CAPABILITY_KEY,
      "H-complexity" => nil
    }.freeze

    def self.applies_to?(experiment) = experiment.slug == Lab.slug_for("metabolism")

    def initialize(experiment:)
      @experiment = experiment
    end

    def call
      Lab::MetabolismReading::Report.new(children: children, arms: arms, tests: tests,
                                         unpiloted_tests: tests(unpiloted: true),
                                         final: DescendantSweepSettledService.call(@experiment))
    end

    private

    def arms
      @arms ||= TREATMENTS.map do |treatment|
        Lab::MetabolismReading::Arm.new(treatment: treatment,
                                        children: children.select { |child| child.treatment == treatment })
      end
    end

    # `unpiloted` re-reads each test without the pairs of Lab::MetabolismReading::PILOT_PARENTS.
    def tests(unpiloted: false)
      reward, no_reward = arms
      twins = no_reward.children.index_by { |child| [child.parent_id, child.seed] }
      treated = unpiloted ? reward.children.reject { |child| piloted?(child) } : reward.children

      HYPOTHESES.map do |hypothesis, key|
        pairs = treated.map { |child| pair(key, child, twins[[child.parent_id, child.seed]]) }
        Lab::FromEmergedHeldout::Test.new(
          hypothesis: unpiloted ? "#{hypothesis}#{Lab::MetabolismReading::UNPILOTED_SUFFIX}" : hypothesis,
          treatment: reward.treatment, comparison: Lab::DescendantReading::Comparison.new(pairs: pairs, kills: false)
        )
      end
    end

    def piloted?(child) = Lab::MetabolismReading::PILOT_PARENTS.include?(child.parent_id)

    def pair(key, treated, control)
      if key
        Lab::MetabolismReading::Pairs::Capability.new(key: key, parent_id: treated.parent_id, seed: treated.seed,
                                                      treated: treated, control: control)
      else
        Lab::FromEmergedHeldout::Pairs::Survivors.new(parent_id: treated.parent_id, seed: treated.seed,
                                                      treated: treated, control: control)
      end
    end

    def children
      @children ||= child_runs.map { |run| child_row(run) }
    end

    def child_row(run)
      samples = own_samples(run)
      settled = samples.select { |epoch, _| epoch > run.parent_epoch + Lab::MetabolismReading::SETTLING_WINDOW }
      reading = Lab::DescendantReading::Child.read(settled, parent_epoch: run.parent_epoch,
                                                            descriptive: Lab::MetabolismReading::DESCRIPTIVE_KEYS)
      ChildRow.new(run_id: run.id, parent_id: run.parent_run_id, seed: run.seed, treatment: treatment_of(run),
                   status: run.status, reading: reading,
                   heldout: Lab::FromEmergedHeldout::Child.read(samples, parent_epoch: run.parent_epoch,
                                                                         last_share: reading.last_share),
                   metabolism: Lab::MetabolismReading::Child.read(samples, parent_epoch: run.parent_epoch),
                   income_share: income_share(run.params, reading))
    end

    def treatment_of(run)
      Lab::MetabolismReading.metabolism_run?(run.params) ? TREATMENTS.first : TREATMENTS.second
    end

    # Task income per cell and epoch, `task_reward × Σ units × share / task_every` over the
    # ladder's last-decile median shares, against the influx: an estimate, since it ignores
    # the stock cap a lump can hit. Nil where a share is missing.
    def income_share(params, reading)
      shares = Lab::MetabolismReading::TASKS.map { |task| reading.last_median(Lab::MetabolismReading.share_key(task)) }
      return nil if shares.any?(&:nil?)

      units = shares.zip(task_units).sum { |share, unit| Rational(share.to_s) * unit }
      income = units * params.fetch("task_reward", 0).to_i / params.fetch("task_every", 1).to_i
      total = income + params.fetch("energy_influx", 0).to_i
      total.zero? ? nil : (income / total).to_f
    end

    def task_units
      @task_units ||= begin
        ladder = Lab::Schema.tasks.fetch("ladder").to_h { |task| [task.fetch("name"), task.fetch("units")] }
        Lab::MetabolismReading::TASKS.map { |task| ladder.fetch(task) }
      end
    end

    def child_runs
      @child_runs ||= @experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed, :id)
                                 .select(:id, :parent_run_id, :parent_epoch, :seed, :params, :status).to_a
    end

    def own_samples(run)
      run.samples.where("epoch > ?", run.parent_epoch).order(:epoch).pluck(:epoch, observed_values)
    end

    def observed_values
      @observed_values ||= Arel.sql(ActiveRecord::Base.sanitize_sql_array(
        ["jsonb_build_object(#{(['?, samples.values -> ?'] * SAMPLE_KEYS.size).join(', ')})",
         *SAMPLE_KEYS.flat_map { |key| [key, key] }]
      ))
    end
  end
end
