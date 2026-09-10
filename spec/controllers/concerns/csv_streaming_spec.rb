# frozen_string_literal: true

require "rails_helper"

RSpec.describe CsvStreaming do
  subject(:controller) do
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    controller_class.new.tap do |instance|
      instance.set_request!(request)
      instance.set_response!(controller_class.make_response!(request))
    end
  end

  let(:controller_class) do
    concern = described_class
    Class.new(ApplicationController) do
      include concern

      def export = stream_csv(Enumerator.new { |lines| lines << "epoch\n" }, filename: "export.csv")
    end
  end

  it "leaves the lines an enumerator for Rack to pull, rather than one joined body" do
    controller.export

    expect(controller.response_body).to be_an(Enumerator)
  end

  it "names the attachment after the given filename" do
    controller.export

    expect(controller.response.headers["Content-Type"]).to eq("text/csv; charset=utf-8")
    expect(controller.response.headers["Content-Disposition"]).to include('attachment; filename="export.csv"')
  end
end
