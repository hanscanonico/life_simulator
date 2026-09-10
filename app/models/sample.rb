# frozen_string_literal: true

class Sample < ApplicationRecord
  belongs_to :run

  validates :epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                    uniqueness: { scope: :run_id }
end
