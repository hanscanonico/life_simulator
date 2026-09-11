# frozen_string_literal: true

# A finding's narrative can point at one run of its own sweep and draw it inline. The run
# is named the way DESIGN §1.1 names a run — its sweep, its arm and its seed — and never by
# a database id, which would differ between the lab and a fresh database.
module FindingsHelper
  def findings_run_chart(experiment_slug:, seed:, metric:, params: {})
    run = findings_cited_run(experiment_slug, seed, params)
    return nil if run.nil?

    points = Runs::MetricSeriesService.call(run: run, metric: metric)
    return nil if points.none?

    findings_run_figure(run, findings_run_line_chart(run, metric, points))
  end

  # A run named in a finding's own table: a link when that run is in this database, its
  # label in plain text when it is not, so the narrative reads the same either way.
  def findings_run_link(experiment_slug:, seed:, params: {}, label: "seed #{seed}")
    run = findings_cited_run(experiment_slug, seed, params)
    return label if run.nil?

    link_to(label, run_path(run))
  end

  # How many runs of a sweep have reached their last epoch, read at render time: a write-up
  # of a sweep that is still going states its own denominator rather than freezing a count
  # that was true on the day it was written.
  def findings_finished_count(experiment_slug:)
    Run.joins(:experiment).where(experiment: { slug: experiment_slug }, status: "finished").count
  end

  private

  # `(params, seed)` identifies a run inside its sweep — a seed alone does not, since every
  # arm of a sweep runs the same seeds — so the caller names the arm it means and the
  # earliest matching run wins.
  def findings_cited_run(experiment_slug, seed, params)
    Run.joins(:experiment).where(experiment: { slug: experiment_slug }, seed: seed).order(:id)
       .find { |run| findings_run_arm?(run, params) }
  end

  def findings_run_arm?(run, params)
    params.all? do |name, value|
      Lab::CanonicalParams.normalise(run.params[name.to_s]) == Lab::CanonicalParams.normalise(value)
    end
  end

  def findings_run_line_chart(run, metric, points)
    title = Runs::ShowPage::METRICS.fetch(metric)
    Charts::LineChart.new(points: points, title: title, x_label: "Epoch", y_label: title,
                          marker: run.transition_epoch)
  end

  def findings_run_figure(run, chart)
    tag.figure(class: "chart-cited") do
      safe_join([render(chart), tag.figcaption(findings_run_caption(run), class: "text-sm text-muted")])
    end
  end

  def findings_run_caption(run)
    safe_join([link_to("Run ##{run.id}", run_path(run)),
               " of the #{run.experiment.name.downcase} sweep, seed #{run.seed}",
               run.transition_epoch ? ", with its transition epoch marked." : "."])
  end
end
