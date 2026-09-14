# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sitemap", type: :request do
  describe "GET /sitemap.xml" do
    it "lists the site's pages as absolute URLs with a last-modified date" do
      get sitemap_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xml")

      document = Nokogiri::XML(response.body)
      expect(document.root.name).to eq("urlset")
      expect(document.root.namespace.href).to eq("http://www.sitemaps.org/schemas/sitemap/0.9")

      locations = document.css("url loc").map(&:text)
      expect(locations).to include("http://www.example.com/", "http://www.example.com/how-it-works")
      expect(locations).to all(start_with("http://www.example.com"))
      expect(document.css("url").map { |url| url.at_css("lastmod")&.text }).to all(match(/\A\d{4}-\d{2}-\d{2}\z/))
    end

    it "carries every finding of the registry, dated as the finding is" do
      finding = Findings::Registry.all.first

      get sitemap_path

      entry = Nokogiri::XML(response.body).css("url").find do |url|
        url.at_css("loc").text.end_with?(finding_path(finding))
      end

      expect(entry).to be_present
      expect(entry.at_css("lastmod").text).to eq(finding.date.iso8601)
    end

    it "carries a new experiment without a code change, dated as it was last touched" do
      experiment = create(:experiment, slug: "late-sweep", updated_at: Time.zone.local(2026, 4, 5))

      get sitemap_path

      entry = Nokogiri::XML(response.body).css("url").find do |url|
        url.at_css("loc").text.end_with?(experiment_path(experiment))
      end

      expect(entry).to be_present
      expect(entry.at_css("lastmod").text).to eq("2026-04-05")
    end

    it "leaves out the pages robots are told not to crawl" do
      create(:experiment)

      get sitemap_path

      locations = Nokogiri::XML(response.body).css("url loc").map(&:text)

      expect(locations).to all(satisfy { |location| !location.match?(%r{/api/|/transitions|/rescores|/up}) })
    end
  end
end
