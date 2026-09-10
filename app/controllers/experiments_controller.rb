# frozen_string_literal: true

class ExperimentsController < ApplicationController
  def index
    @index = Experiments::IndexPage.build
  end

  def show
    experiment = Experiment.find_by!(slug: params.expect(:id))
    @show = Experiments::ShowPage.build(experiment: experiment, paginate: method(:pagy))
  end
end
