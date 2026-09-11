# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Error pages", type: :request do
  describe "the static files" do
    { "404" => "No page at this address",
      "422" => "The change was rejected",
      "500" => "Something broke on our side" }.each do |code, heading|
      it "brands public/#{code}.html and keeps it out of the index" do
        page = Rails.public_path.join("#{code}.html").read

        expect(page).to include(
          %(<meta name="robots" content="noindex, nofollow">),
          %(<a class="wordmark" href="/">Life Simulator</a>),
          %(<a href="/">Home</a>),
          %(<a href="/findings">Findings</a>),
          %(<a href="/experiments">Experiments</a>),
          heading
        )
      end
    end
  end

  describe "GET an unknown finding with production's error handling" do
    # env_config wins over anything passed to `get`, so production's handling has to be
    # stubbed there: raise through to the exceptions app, without the debug page.
    before do
      allow(Rails.application).to receive(:env_config).and_return(
        Rails.application.env_config.merge("action_dispatch.show_exceptions" => :all,
                                           "action_dispatch.show_detailed_exceptions" => false)
      )
    end

    it "serves the branded 404 page" do
      get "/findings/not-a-finding"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("No page at this address", %(<a href="/findings">Findings</a>))
    end
  end
end
