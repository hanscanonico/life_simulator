# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Structured data", type: :request do
  def blocks_of(path)
    get path
    response.parsed_body.css("script[type='application/ld+json']")
  end

  def payload_of(path)
    blocks = blocks_of(path)
    expect(blocks.size).to eq(1)

    JSON.parse(blocks.first.text)
  end

  describe "GET /" do
    it "declares the site" do
      payload = payload_of(root_path)

      expect(payload).to include("@context" => "https://schema.org", "@type" => "WebSite",
                                 "name" => "Life Simulator", "url" => root_url)
      expect(payload["description"]).to include("soup of programs")
      expect(payload["publisher"]).to include("@type" => "Organization")
    end
  end

  describe "GET /findings/:id" do
    it "declares every write-up as an article, whatever its status" do
      Findings::Registry::ALL.each do |finding|
        payload = payload_of(finding_path(finding))

        expect(payload).to include("@context" => "https://schema.org", "@type" => "ScholarlyArticle",
                                   "headline" => finding.title,
                                   "datePublished" => finding.date.iso8601,
                                   "description" => finding.summary.squish.truncate(155))
        expect(payload["author"]).to include("@type" => "Organization", "name" => "Life Simulator")
        expect(payload["publisher"]).to eq(payload["author"])
      end
    end

    it "points the article at the page the head calls canonical" do
      finding = Findings::Registry.all.first

      get finding_path(finding)
      payload = JSON.parse(response.parsed_body.css("script[type='application/ld+json']").first.text)

      canonical = response.parsed_body.css("link[rel=canonical]").attribute("href").value
      expect(payload["url"]).to eq(canonical)
      expect(payload["mainEntityOfPage"]).to eq(canonical)
      expect(payload["image"]).to eq(URI.join(root_url, "icon.png").to_s)
    end
  end

  describe "a page with nothing to declare" do
    it "emits no block at all" do
      expect(blocks_of(findings_path)).to be_empty
      expect(blocks_of(experiments_path)).to be_empty
    end
  end
end
