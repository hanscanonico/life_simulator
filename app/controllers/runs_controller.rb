# frozen_string_literal: true

class RunsController < ApplicationController
  include CsvStreaming

  PROGRESS_FRAME = "run_progress"

  # A poll of the progress frame asks for this same action, so answer it with the frame
  # alone rather than the charts and snapshots Turbo would throw away.
  def show
    @show = Runs::ShowPage.build(run: Run.find(params.expect(:id)))
    return unless turbo_frame_request_id == PROGRESS_FRAME

    render partial: "runs/progress", locals: { show: @show, polling: false }
  end

  def samples
    run = Run.find(params.expect(:id))
    stream_csv(Runs::SamplesCsvService.call(run: run), filename: "run-#{run.id}-samples.csv")
  end
end
