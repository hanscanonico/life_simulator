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
end
