# frozen_string_literal: true

class RunsController < ApplicationController
  def show
    @show = Runs::ShowPage.build(run: Run.find(params.expect(:id)))
  end
end
