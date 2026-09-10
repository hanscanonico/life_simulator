# frozen_string_literal: true

class Experiment < ApplicationRecord
  STATUSES = %w[draft queued running finished].freeze

  enum :status, STATUSES.index_by(&:itself), validate: true

  has_many :runs, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :substrate, presence: true
  validates :epochs, numericality: { only_integer: true, greater_than: 0 }
  validates :priority, numericality: { only_integer: true }

  def to_param = slug
end
