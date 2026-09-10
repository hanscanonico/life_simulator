# frozen_string_literal: true

class RunsController < ApplicationController
  include CsvStreaming

  def show
    @show = Runs::ShowPage.build(run: Run.find(params.expect(:id)))
  end

  def samples
    run = Run.find(params.expect(:id))
    stream_csv(Runs::SamplesCsvService.call(run: run), filename: "run-#{run.id}-samples.csv")
  end
end
