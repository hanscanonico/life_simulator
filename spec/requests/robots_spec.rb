# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Robots", type: :request do
  describe "GET /robots.txt" do
    it "points crawlers at the sitemap and keeps them off the machine-facing paths" do
      get robots_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/plain")
      expect(response.body.split("\n").map(&:strip).reject(&:empty?)).to eq(
        [
          "User-agent: *",
          "Disallow: /api/",
          "Disallow: /experiments/*.csv",
          "Disallow: /experiments/*/transitions",
          "Disallow: /experiments/*/rescores",
          "Disallow: /runs/*/samples",
          "Disallow: /lab/status",
          "Disallow: /up",
          "Sitemap: http://www.example.com/sitemap.xml"
        ]
      )
    end

    it "leaves the public pages crawlable" do
      get robots_path

      expect(response.body).not_to include("Disallow: /\n", "Disallow: /lab\n", "Disallow: /sitemap.xml")
    end

    it "keeps the experiment pages crawlable while barring their runs export" do
      get robots_path

      disallowed = response.body.scan(/^Disallow: (.+)$/).flatten
      expect(disallowed).to include("/experiments/*.csv")
      expect(disallowed).not_to include("/experiments", "/experiments/", "/experiments/*")
    end
  end
end
