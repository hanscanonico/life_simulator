# frozen_string_literal: true

module Runs
  # Moves a batch of runs in one boot. `bin/rails` runs a rake task once per invocation
  # whatever its arguments, so reordering a sweep one run at a time costs one Rails boot per
  # run; this takes the whole batch as `id:priority;id:priority` and applies it in one
  # transaction. Every pair is checked — shape, unknown run, terminal run — before anything
  # is written, so a typo in the tail of a long batch moves nothing.
  class SetPrioritiesService
    include Callable

    PAIR = /\A(\d+):(-?\d+)\z/

    def initialize(pairs:)
      @pairs = pairs
    end

    def call
      requested = parse
      runs = load_runs(requested.keys)

      Run.transaction do
        requested.map do |run_id, priority|
          run = runs.fetch(run_id)
          PriorityMove.new(run: run, previous: SetPriorityService.call(run: run, priority: priority),
                           priority: priority)
        end
      end
    end

    private

    def parse
      fields = @pairs.to_s.split(";").map(&:strip).reject(&:empty?)
      raise ArgumentError, "Give at least one pair, as lab:prioritise_runs[12:40;13:39]." if fields.empty?

      malformed = fields.grep_v(PAIR)
      if malformed.any?
        raise ArgumentError, "Malformed pairs #{malformed.map(&:inspect).join(', ')}; expected id:priority."
      end

      fields.to_h do |field|
        run_id, priority = PAIR.match(field).captures
        [run_id.to_i, priority.to_i]
      end
    end

    def load_runs(run_ids)
      runs = Run.where(id: run_ids).index_by(&:id)
      unknown = run_ids - runs.keys
      raise ArgumentError, "Unknown runs #{unknown.join(', ')}." if unknown.any?

      terminal = runs.values.select(&:terminal?)
      if terminal.any?
        raise ArgumentError,
              "Terminal runs #{terminal.map(&:id).join(', ')}; only a pending, claimed or running run can be " \
              "reprioritised."
      end

      runs
    end
  end
end
