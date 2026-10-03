# frozen_string_literal: true

# The topless-rise sweep, its parents in the meta-stack sweep and its children's own samples,
# for the specs of its builder and its reading.
module ToplessRiseRuns
  def topless_rise_experiment
    definition = Lab::SWEEPS.fetch("topless_rise")
    create(:experiment, name: "Topless rise", slug: "topless-rise",
                        **definition.slice(:parents, :param_grid, :seeds, :epochs, :priority))
  end

  # The meta-stack sweep seeded from `count` metabolism parents, every child finished with its
  # last world stored, so each meta-stack-arm child, three a metabolism parent, qualifies as a
  # topless-rise parent; returns those children in (parent, seed) order.
  def topless_rise_parents(count: 1)
    experiment = Experiment.find_by(slug: "meta-stack") || meta_stack_experiment
    count.times { metabolism_parent }
    Experiments::DescendantSweepBuilderService.call(experiment)
    experiment.runs.where.not(parent_run_id: nil).find_each do |run|
      run.update!(status: "finished")
      create(:snapshot, run: run, epoch: run.epochs) unless run.snapshots.exists?(epoch: run.epochs)
    end
    meta_stack_children(experiment, :meta_stack)
  end

  # The children of one arm, `:rise`, `:capped` or `:none`, in (parent, seed) order.
  def topless_rise_children(experiment, treatment)
    experiment.runs.where.not(parent_run_id: nil).order(:parent_run_id, :seed)
              .select { |run| Lab::ToplessRiseReading.treatment_key(run.params) == treatment }
  end

  # 200 own samples 10 epochs apart from the parent epoch, so the last 100 are past the
  # settling window: its fifth decile is samples 140–149 and its last 190–199. `logic_depth_max`
  # reads `fifth` until the last decile and `last` there, unless `depth` gives it per sample
  # index; `share` may be a value or a lambda of the index.
  def topless_rise_sample(run, fifth: 9, last: fifth, depth: nil, share: 0.9, status: "finished")
    depths = depth || ->(index) { index >= 190 ? last : fifth }
    insert_own_samples(run, Array.new(200) do |index|
      { "replicator_share" => topless_at(share, index), "logic_depth_max" => topless_at(depths, index),
        "logic_depth_classes" => 2 }
    end)
    run.update!(status: status)
  end

  private

  def topless_at(value, index) = value.respond_to?(:call) ? value.call(index) : value
end

RSpec.configure { |config| config.include ToplessRiseRuns }
