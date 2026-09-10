# frozen_string_literal: true

# Sends CSV lines as an enumerator body: Rack pulls the lines as it writes them, so an
# export is never materialised as one string on top of the rows it was built from.
module CsvStreaming
  extend ActiveSupport::Concern

  private

  def stream_csv(lines, filename:)
    response.headers["Content-Type"] = "text/csv; charset=utf-8"
    response.headers["Content-Disposition"] =
      ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: filename)
    self.response_body = lines
  end
end
