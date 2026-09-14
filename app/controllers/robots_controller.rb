# frozen_string_literal: true

class RobotsController < ApplicationController
  def show
    render layout: false, content_type: "text/plain"
  end
end
