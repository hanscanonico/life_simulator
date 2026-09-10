# frozen_string_literal: true

namespace :lab do
  desc "Build a sweep experiment from DESIGN.md 1.3 (mutation_rate, world_size, radius, max_steps, ops)"
  task :sweep, [:sweep] => :environment do |_task, args|
    definition = Lab::SWEEPS[args[:sweep]]
    raise "Unknown sweep #{args[:sweep].inspect}. Known sweeps: #{Lab::SWEEPS.keys.join(', ')}" if definition.nil?

    experiment = Experiment.find_or_initialize_by(slug: args[:sweep].tr("_", "-"))
    experiment.update!(definition.merge(substrate: "soup"))
    Experiments::SweepBuilderService.call(experiment)

    puts "#{experiment.name}: #{experiment.reload.runs_count} runs"
  end

  desc "Send the failed runs of an experiment back to the pending queue"
  task :requeue_failed, [:slug] => :environment do |_task, args|
    experiment = Experiment.find_by(slug: args[:slug])
    raise "Unknown experiment #{args[:slug].inspect}." if experiment.nil?

    requeued = Runs::RequeueFailedService.call(experiment: experiment)

    puts "#{experiment.name}: #{requeued} failed runs back to pending"
  end

  desc "Set the queue priority of an experiment and of its pending runs"
  task :prioritise, [:slug, :priority] => :environment do |_task, args|
    experiment = Experiment.find_by(slug: args[:slug])
    raise "Unknown experiment #{args[:slug].inspect}." if experiment.nil?
    raise "Priority #{args[:priority].inspect} is not an integer." unless /\A-?\d+\z/.match?(args[:priority].to_s)

    priority = args[:priority].to_i
    pending = Experiments::SetPriorityService.call(experiment: experiment, priority: priority)

    puts "#{experiment.name}: priority #{priority}, #{pending} pending runs"
  end

  desc "Recompute transition_epoch from the stored samples of terminal runs (one experiment, or all)"
  task :backfill_transitions, [:slug] => :environment do |_task, args|
    runs = Run.terminal.order(:id)
    if args[:slug].present?
      experiment = Experiment.find_by(slug: args[:slug])
      raise "Unknown experiment #{args[:slug].inspect}." if experiment.nil?

      runs = runs.where(experiment: experiment)
    end

    terminal = runs.to_a
    backfilled = terminal.count do |run|
      recomputed = Runs::TransitionEpochService.call(run: run)
      next false if recomputed == run.transition_epoch

      puts "run #{run.id}: #{run.transition_epoch || 'none'} → #{recomputed || 'none'}"
      run.update!(transition_epoch: recomputed)
      true
    end

    puts "backfilled #{backfilled} of #{terminal.size} terminal runs"
  end

  desc "Thin the snapshots of every terminal run (one-off; the recurring job covers new runs)"
  task prune_snapshots: :environment do
    deleted = Run.terminal.find_each.sum { |run| Runs::PruneSnapshotsService.call(run: run) }

    puts "pruned #{deleted} snapshots"
  end

  desc "Print the size of the lab database and of its two heaviest tables"
  task db_size: :environment do
    connection = ActiveRecord::Base.connection
    puts "database: #{connection.select_value('SELECT pg_size_pretty(pg_database_size(current_database()))')}"
    %w[samples snapshots].each do |table|
      size = connection.select_value("SELECT pg_size_pretty(pg_total_relation_size('#{table}'))")
      puts "#{table}: #{size}"
    end
  end
end
