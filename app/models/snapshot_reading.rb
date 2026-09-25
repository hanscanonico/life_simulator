# frozen_string_literal: true

# One instrument's reading of a run, taken after the fact from a world the run stored:
# the world at `source_epoch` is restored and stepped to `epoch`, where the instrument
# reads it. These are not samples — a run's samples are the live record and are never
# written after it ends — and they outlive the worlds they came from: pruning snapshots
# never touches them (DESIGN.md §2).
class SnapshotReading < ApplicationRecord
  # A name and a version, so a changed instrument never overwrites its predecessor's
  # readings: `oriented_census/1`.
  INSTRUMENT_FORMAT = %r{\A[a-z][a-z0-9_]*/\d+\z}

  belongs_to :run

  validates :epoch, :source_epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :instrument, format: { with: INSTRUMENT_FORMAT }
  validate :read_from_an_earlier_world
  validate :values_are_an_object

  private

  # The instrument reads the world a few epochs after the stored one it was stepped from.
  def read_from_an_earlier_world
    return unless epoch.is_a?(Integer) && source_epoch.is_a?(Integer) && source_epoch > epoch

    errors.add(:source_epoch, "must not be after the epoch it was read at")
  end

  def values_are_an_object
    errors.add(:values, "must be an object") unless values.is_a?(Hash)
  end
end
