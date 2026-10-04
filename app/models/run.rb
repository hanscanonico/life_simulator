# frozen_string_literal: true

class Run < ApplicationRecord
  STATUSES = %w[pending claimed running finished failed].freeze
  TERMINAL_STATUSES = %w[finished failed].freeze
  # The runner heartbeats every 30 s (DESIGN.md §2); a run silent for this long is orphaned.
  STALE_AFTER = 5.minutes

  enum :status, STATUSES.index_by(&:itself), validate: true

  belongs_to :experiment, counter_cache: true
  # A descendant restores its parent's world at `parent_epoch` (DESIGN.md §1.1), so a
  # parent that still has one cannot be deleted from under it.
  belongs_to :parent_run, class_name: "Run", optional: true, inverse_of: :descendants
  has_many :descendants, class_name: "Run", foreign_key: :parent_run_id, inverse_of: :parent_run,
                         dependent: :restrict_with_exception
  has_many :samples, dependent: :destroy
  has_many :snapshots, dependent: :destroy
  has_many :rescores, dependent: :destroy
  has_many :snapshot_readings, dependent: :destroy

  validates :seed, numericality: { only_integer: true }
  validates :epochs, numericality: { only_integer: true, greater_than: 0 }
  validates :epochs_done, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :priority, numericality: { only_integer: true }
  validate :descends_from_a_stored_world, on: :create, if: :descendant?

  scope :terminal, -> { where(status: TERMINAL_STATUSES) }
  # A run started from its own random fill rather than from a parent's world: the only
  # runs a transition or an emergence reading surveys, since a descendant inherits its
  # parent's emergence and never crosses anything of its own.
  scope :founding, -> { where(parent_run_id: nil) }
  # A run the detector flagged and that will not run again — failures included, since a
  # world that crossed before its runner died still crossed.
  scope :transitioned, -> { founding.terminal.where.not(transition_epoch: nil) }
  # A run whose crossing a witness backs (docs/design_record.md, 2026-09-15): the detector
  # flags a candidate, and only these emerged.
  scope :emerged, -> { founding.terminal.where.not(emergence_epoch: nil) }
  scope :stale, -> { where(status: %w[claimed running]).where(heartbeat_at: ...STALE_AFTER.ago) }
  # A run paid for its tasks imports an objective (DESIGN.md §1.4) and is never pooled with
  # a fitness-free one: every site-wide or cross-sweep aggregate reads `fitness_free`. A run
  # stored before the parameter existed carries no key, and a missing reward is no reward.
  # The engine reads the reward only as a JSON number, so anything else is no reward too,
  # and is never cast: one malformed value would otherwise fail every page's status strip.
  # Keep in step with Lab::MetabolismReading.metabolism_run?, the same rule on a params hash.
  REWARD_SQL = "CASE jsonb_typeof(runs.params -> '#{Lab::MetabolismReading::REWARD_KEY}') WHEN 'number' " \
               "THEN (runs.params ->> '#{Lab::MetabolismReading::REWARD_KEY}')::numeric ELSE 0 END".freeze
  # A run whose predation pass runs moves energy by what its tapes compute: it imports a
  # machine, not an objective (DESIGN.md §1.4), and is never pooled with plain Soup either.
  # Keep in step with Lab::OutComputeReading.predatory_run?, the same rule on a params hash.
  PREDATION_SQL = "runs.params -> '#{Lab::OutComputeReading::PREDATION_KEY}'".freeze
  TRANSFER_SQL = "runs.params -> '#{Lab::OutComputeReading::TRANSFER_KEY}'".freeze
  PREDATORY_SQL = "jsonb_typeof(#{PREDATION_SQL}) = 'string' " \
                  "AND #{PREDATION_SQL} <> '\"#{Lab::OutComputeReading::OFF}\"'::jsonb " \
                  "AND CASE jsonb_typeof(#{TRANSFER_SQL}) WHEN 'number' THEN (#{TRANSFER_SQL})::numeric ELSE 0 END > 0"
                  .freeze
  # A run whose fidelity level is priced pays for a heritable machine state, predation or
  # not: it imports a machine too. Keep in step with Lab::GenesRiseReading.priced_fidelity_run?.
  FIDELITY_MAX_SQL = "runs.params -> '#{Lab::GenesRiseReading::FIDELITY_MAX_KEY}'".freeze
  FIDELITY_ALPHA_SQL = "runs.params -> '#{Lab::GenesRiseReading::FIDELITY_ALPHA_KEY}'".freeze
  PRICED_FIDELITY_SQL = "CASE jsonb_typeof(#{FIDELITY_MAX_SQL}) WHEN 'number' THEN (#{FIDELITY_MAX_SQL})::numeric " \
                        "ELSE 0 END > 0 AND CASE jsonb_typeof(#{FIDELITY_ALPHA_SQL}) WHEN 'number' " \
                        "THEN (#{FIDELITY_ALPHA_SQL})::numeric ELSE 0 END > 0".freeze
  MACHINE_SQL = "(#{PREDATORY_SQL}) OR (#{PRICED_FIDELITY_SQL})".freeze
  scope :metabolism, -> { where("#{REWARD_SQL} > 0") }
  scope :predatory, -> { where(PREDATORY_SQL) }
  scope :priced_fidelity, -> { where(PRICED_FIDELITY_SQL) }
  # The runs that import a machine, not an objective (DESIGN.md §1.4).
  scope :machine, -> { where(MACHINE_SQL) }
  # The runs that carry a label, an objective or a machine: never pooled with plain Soup.
  scope :labelled, -> { metabolism.or(machine) }
  scope :fitness_free, -> { where("#{REWARD_SQL} <= 0").where.not(MACHINE_SQL) }

  # A run started from `parent`'s stored world at `epoch` — by default the latest one the
  # parent kept — for `budget` more epochs, under `params` that may change the parent's
  # dynamics but not its structure. The epoch count continues the parent's, and the
  # emergence the child cannot read for itself is the parent's, carried over.
  def self.descend_from(parent, params:, seed:, budget:, experiment:, epoch: nil)
    epoch ||= parent.snapshots.restorable.maximum(:epoch)

    experiment.runs.create!(parent_run: parent, parent_epoch: epoch, params: params, seed: seed,
                            epochs: epoch.to_i + budget, epochs_done: epoch.to_i, priority: experiment.priority,
                            **parent.emergence.attributes)
  end

  def terminal? = TERMINAL_STATUSES.include?(status)

  def descendant? = parent_run_id.present?

  # What a descendant may not change about its parent's world (Lab::CanonicalParams).
  def structure = Lab::CanonicalParams.structure_of(params, substrate: experiment&.substrate)

  # The epoch a run's own simulation started from: 0 for a founding run. `epochs` and
  # `epochs_done` count on from the parent's clock, so what this run itself simulated is
  # read from here.
  def start_epoch = parent_epoch.to_i

  def own_epochs = epochs - start_epoch

  def own_epochs_done = epochs_done - start_epoch

  # How long the colony had stood at `epoch`, counted from the emergence the run carries
  # — a descendant's is its parent's, so the age runs on across the descent.
  def colony_age_at(epoch) = emergence_epoch && (epoch - emergence_epoch)

  # The read-side derivation of Runs::PersistenceSummaryService, stored with the run so a
  # sweep page can read a whole arm's persistence without reading a sample.
  def persistence_summary = Runs::Persistence.from(persistence)

  def emergence = Runs::Emergence.new(epoch: emergence_epoch, witness: emergence_witness)

  def emerged? = emergence_epoch.present?

  def claimed_by?(other_runner_id) = runner_id.present? && runner_id == other_runner_id

  # One value of an instrument's readings of the run's stored worlds, `[[epoch, value], ...]`
  # in epoch order; a reading that lacks the key reads nil.
  def readings_series(instrument, key)
    value = Arel::Nodes::InfixOperation.new("->", SnapshotReading.arel_table[:values],
                                            Arel::Nodes.build_quoted(key.to_s))
    snapshot_readings.where(instrument: instrument).order(:epoch).pluck(:epoch, value)
  end

  # The transition is the FIRST qualifying epoch (DESIGN.md §2), so a resumed runner
  # reporting a later one — or a retried batch — never replaces an epoch already recorded.
  # A descendant records none: its world had crossed before it started, and a crossing its
  # runner reads off the already-transitioned series is no transition.
  def earlier_transition_epoch?(epoch)
    return false if epoch.blank? || descendant?

    transition_epoch.nil? || epoch.to_i < transition_epoch
  end

  # The same guard for the companion reading (docs/design_record.md, 2026-09-19).
  def earlier_transition_epoch_relative?(epoch)
    return false if epoch.blank? || descendant?

    transition_epoch_relative.nil? || epoch.to_i < transition_epoch_relative
  end

  private

  def descends_from_a_stored_world
    return errors.add(:parent_run, "must be a stored run") if parent_run.nil?

    errors.add(:params, "must keep the parent's structure") unless structure == parent_run.structure
    unless parent_run.snapshots.restorable.exists?(epoch: parent_epoch)
      errors.add(:parent_epoch, "must be an epoch the parent stored a world at")
    end
    errors.add(:epochs, "must run past the parent epoch") unless epochs.to_i > parent_epoch.to_i
    # The engine refuses to descend from inside the relative tracker's baseline window
    # (`World::descend`), so a child started there could never be claimed.
    return if parent_epoch.to_i > Lab::TransitionRule::BASELINE_EPOCHS

    errors.add(:parent_epoch, "must lie past the baseline window (epoch #{Lab::TransitionRule::BASELINE_EPOCHS})")
  end
end
