# frozen_string_literal: true

module Sitemaps
  # Every page a crawler should know about, as paths and last-modified dates. The
  # hand-written pages and the findings index carry the newest finding's date: their copy
  # is versioned with the findings narrative in the repo, and the home page digests it.
  class ShowPage
    include Rails.application.routes.url_helpers

    Entry = Data.define(:path, :lastmod)

    def self.build = new

    def entries = index_entries + finding_entries + experiment_entries

    private

    def index_entries
      [Entry.new(path: root_path, lastmod: newest_finding_date),
       Entry.new(path: how_it_works_path, lastmod: newest_finding_date),
       Entry.new(path: findings_path, lastmod: newest_finding_date),
       Entry.new(path: experiments_path, lastmod: newest_experiment_date)]
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

    def newest_experiment_date
      @newest_experiment_date ||= experiments.filter_map { |experiment| experiment.updated_at&.to_date }.max ||
                                  newest_finding_date
    end
  end
end
