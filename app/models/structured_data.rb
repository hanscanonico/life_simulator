# frozen_string_literal: true

# What a crawler reads instead of the prose: schema.org payloads for the pages that have
# something machine-readable to declare. The site names no individual author anywhere, so
# it authors and publishes its own write-ups as an organisation.
module StructuredData
  CONTEXT = "https://schema.org"
  SITE_NAME = "Life Simulator"

  def self.website(url:, description:)
    {
      "@context" => CONTEXT,
      "@type" => "WebSite",
      "name" => SITE_NAME,
      "url" => url,
      "description" => description,
      "publisher" => organization(url)
    }
  end

  # A finding is a claim written up against its own runs, which is what a ScholarlyArticle
  # is; `url` and `mainEntityOfPage` both name the canonical page so neither reading of the
  # vocabulary is left guessing.
  def self.scholarly_article(finding:, url:, site_url:, description:, image:)
    {
      "@context" => CONTEXT,
      "@type" => "ScholarlyArticle",
      "headline" => finding.title,
      "description" => description,
      "datePublished" => finding.date.iso8601,
      "url" => url,
      "mainEntityOfPage" => url,
      "image" => image,
      "author" => organization(site_url),
      "publisher" => organization(site_url)
    }
  end

  def self.organization(url) = { "@type" => "Organization", "name" => SITE_NAME, "url" => url }
end
