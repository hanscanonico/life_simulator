# frozen_string_literal: true

class Run < ApplicationRecord
  STATUSES = %w[pending claimed running finished failed].freeze
  TERMINAL_STATUSES = %w[finished failed].freeze
  # The runner heartbeats every 30 s (DESIGN.md §2); a run silent for this long is orphaned.
  STALE_AFTER = 5.minutes

  enum :status, STATUSES.index_by(&:itself), validate: true

  belongs_to :experiment, counter_cache: true
  has_many :samples, dependent: :destroy
  has_many :snapshots, dependent: :destroy
  has_many :rescores, dependent: :destroy

  validates :seed, numericality: { only_integer: true }
  validates :epochs, numericality: { only_integer: true, greater_than: 0 }
  validates :epochs_done, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :priority, numericality: { only_integer: true }

  scope :terminal, -> { where(status: TERMINAL_STATUSES) }
  scope :stale, -> { where(status: %w[claimed running]).where(heartbeat_at: ...STALE_AFTER.ago) }

  def terminal? = TERMINAL_STATUSES.include?(status)

  # The read-side derivation of Runs::PersistenceSummaryService, stored with the run so a
  # sweep page can read a whole arm's persistence without reading a sample.
  def persistence_summary = Runs::Persistence.from(persistence)

  def claimed_by?(other_runner_id) = runner_id.present? && runner_id == other_runner_id

  # The transition is the FIRST qualifying epoch (DESIGN.md §2), so a resumed runner
  # reporting a later one — or a retried batch — never replaces an epoch already recorded.
  def earlier_transition_epoch?(epoch)
    return false if epoch.blank?

    transition_epoch.nil? || epoch.to_i < transition_epoch
  end
end
