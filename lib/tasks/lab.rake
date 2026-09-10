# frozen_string_literal: true

namespace :lab do
  desc "Build a sweep experiment from DESIGN.md 1.3 (mutation_rate, world_size, radius)"
  task :sweep, [:sweep] => :environment do |_task, args|
    definition = Lab::SWEEPS[args[:sweep]]
    raise "Unknown sweep #{args[:sweep].inspect}. Known sweeps: #{Lab::SWEEPS.keys.join(', ')}" if definition.nil?

    experiment = Experiment.find_or_initialize_by(slug: args[:sweep].tr("_", "-"))
    experiment.update!(definition.merge(substrate: "soup"))
    Experiments::SweepBuilderService.call(experiment)

    puts "#{experiment.name}: #{experiment.reload.runs_count} runs"
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
