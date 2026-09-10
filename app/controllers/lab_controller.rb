# frozen_string_literal: true

class LabController < ApplicationController
  def show; end

  def status
    @status = Lab::StatusPage.build
  end
end
