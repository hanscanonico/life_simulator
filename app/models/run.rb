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

  validates :seed, numericality: { only_integer: true }
  validates :epochs, numericality: { only_integer: true, greater_than: 0 }
  validates :epochs_done, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :terminal, -> { where(status: TERMINAL_STATUSES) }
  scope :stale, -> { where(status: %w[claimed running]).where(heartbeat_at: ...STALE_AFTER.ago) }

  def terminal? = TERMINAL_STATUSES.include?(status)

  def claimed_by?(other_runner_id) = runner_id.present? && runner_id == other_runner_id
end
