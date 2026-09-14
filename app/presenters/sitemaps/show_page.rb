# frozen_string_literal: true

module Sitemaps
  # Every page a crawler should know about, as paths and last-modified dates. The two
  # hand-written pages carry the newest finding's date: their copy is versioned with the
  # findings narrative in the repo, and the home page digests it.
  class ShowPage
    include Rails.application.routes.url_helpers

    Entry = Data.define(:path, :lastmod)

    def self.build = new

    def entries = static_entries + finding_entries + experiment_entries

    private

    def static_entries
      [Entry.new(path: root_path, lastmod: newest_finding_date),
       Entry.new(path: how_it_works_path, lastmod: newest_finding_date)]
    end

    def finding_entries
      findings.map { |finding| Entry.new(path: finding_path(finding), lastmod: finding.date) }
    end

    def experiment_entries
      experiments.map do |experiment|
        Entry.new(path: experiment_path(experiment), lastmod: experiment.updated_at.to_date)
      end
    end

    def findings = @findings ||= Findings::Registry.all

    def experiments = @experiments ||= Experiment.order(:name).to_a

    def newest_finding_date = @newest_finding_date ||= findings.first&.date || Date.current
  end
end
