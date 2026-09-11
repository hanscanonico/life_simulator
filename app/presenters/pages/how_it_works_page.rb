# frozen_string_literal: true

module Pages
  # The programme of DESIGN §1.3 as the how-it-works page reads it: the sweeps in the order
  # Lab::SWEEPS declares them, each pointed at its write-up if one cites it and at its
  # sweep page if the lab has queued it. The positive control is held out of the numbered
  # sweeps: it is the design record's addition, not one of the five questions.
  class HowItWorksPage
    CONTROL_KEY = "bff_control"

    Sweep = Data.define(:name, :description, :experiment, :finding) do
      def experiment? = experiment.present?

      def finding? = finding.present?
    end

    def self.build = new

    def sweeps = @sweeps ||= (Lab::SWEEPS.keys - [CONTROL_KEY]).map { |key| sweep_for(key) }

    def control = @control ||= sweep_for(CONTROL_KEY)

    private

    def sweep_for(key)
      definition = Lab::SWEEPS.fetch(key)
      name = definition.fetch(:name)
      slug = Lab.slug_for(key)

      Sweep.new(name: name, description: definition.fetch(:description),
                experiment: experiments_by_slug[slug] || experiments_by_name[name.downcase],
                finding: findings_by_slug[slug])
    end

    # A sweep built by hand can carry any slug, so its name is the second way to recognise
    # it — the same rule the experiment list plans by.
    def experiments_by_name = @experiments_by_name ||= experiments.index_by { |experiment| experiment.name.downcase }

    def experiments_by_slug = @experiments_by_slug ||= experiments.index_by(&:slug)

    def experiments = @experiments ||= Experiment.order(:name).to_a

    # Newest first from the registry, so a sweep written up twice links to its latest
    # write-up.
    def findings_by_slug
      @findings_by_slug ||= Findings::Registry.all.group_by(&:experiment_slug).transform_values(&:first)
    end
  end
end
