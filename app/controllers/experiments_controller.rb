# frozen_string_literal: true

class ExperimentsController < ApplicationController
  include CsvStreaming

  def index
    @index = Experiments::IndexPage.build
  end

  def show
    experiment = Experiment.find_by!(slug: params.expect(:id))
    respond_to do |format|
      format.html { @show = Experiments::ShowPage.build(experiment: experiment, paginate: method(:pagy)) }
      format.csv do
        stream_csv(Experiments::RunsCsvService.call(experiment: experiment), filename: "#{experiment.slug}-runs.csv")
      end
    end
  end
end
