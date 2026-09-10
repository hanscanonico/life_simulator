# frozen_string_literal: true

module Findings
  # The findings log: every published claim, newest first, with the sweep it rests on.
  class IndexPage
    Row = Data.define(:finding, :experiment) do
      def experiment? = experiment.present?
    end

    def self.build = new

    def rows
      @rows ||= Registry.all.map do |finding|
        Row.new(finding: finding, experiment: experiments[finding.experiment_slug])
      end
    end

    def any? = rows.present?

    private

    # An experiment named by a finding may not exist yet (the sweep is queued by hand),
    # and that must not take the page down.
    def experiments
      @experiments ||= Experiment.where(slug: Registry.all.map(&:experiment_slug)).index_by(&:slug)
    end
  end
end
