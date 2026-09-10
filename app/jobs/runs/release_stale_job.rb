# frozen_string_literal: true

module Runs
  class ReleaseStaleJob < ApplicationJob
    queue_as :default

    def perform = ReleaseStaleService.call
  end
end
