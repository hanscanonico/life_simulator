# frozen_string_literal: true

class Snapshot < ApplicationRecord
  belongs_to :run

  # A snapshot with no world bytes cannot restore a run, only illustrate it.
  scope :restorable, -> { where.not(blob: nil) }

  validates :epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                    uniqueness: { scope: :run_id }
end
