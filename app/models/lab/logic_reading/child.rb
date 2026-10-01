# frozen_string_literal: true

module Lab
  module LogicReading
    # One child's own samples — `[[epoch, values], ...]` above its parent epoch, in epoch
    # order — read for what the logic entry adds to the from-emerged rules, as
    # Lab::MetabolismReading::Child reads the arithmetic ladder. The tests' values are read
    # past the settling window: the last decile is the last `ceil(n / 10)` of all `n` settled
    # samples, unfiltered, and inside it the samples that carry the key as a number, their
    # median Findings::Median's lower middle. The rungs' first epochs are descriptive, read
    # over every own sample, the window included, under the persistence rule.
    class Child
      Reading = Data.define(:capabilities, :first_epochs, :dominant_tasks) do
        # The last-decile median of `logic_capability` or `logic_capability_deep`; nil where
        # the decile holds fewer than MIN_DECILE_SAMPLES of them.
        def capability(key) = capabilities[key]

        # The first own epoch a deep rung reached the line; nil if none did.
        def deep_epoch = first_epochs.values_at(*DEEP_TASKS).compact.min

        def climbed_deep? = !deep_epoch.nil?

        # A deep rung arose where OR, ANDN or NOR had already reached the line, at or before it.
        def stepping_stone?
          climbed_deep? && first_epochs.values_at(*STEPPING_STONES).compact.any? { |epoch| epoch <= deep_epoch }
        end
      end

      def self.read(samples, parent_epoch:)
        new(samples, parent_epoch: parent_epoch).reading
      end

      def initialize(samples, parent_epoch:)
        @samples = samples
        @settled = samples.select { |epoch, _| epoch > parent_epoch + SETTLING_WINDOW }
      end

      def reading
        Reading.new(capabilities: [CAPABILITY_KEY, DEEP_CAPABILITY_KEY].index_with { |key| capability(key) },
                    first_epochs: TASKS.index_with { |task| first_epoch(LogicReading.share_key(task)) },
                    dominant_tasks: dominant_tasks)
      end

      private

      def last_decile = @settled.last((@settled.size + 9) / 10)

      def numbers(key) = last_decile.filter_map { |_, values| values[key] if values[key].is_a?(Numeric) }

      def capability(key)
        values = numbers(key)
        values.size < MIN_DECILE_SAMPLES ? nil : Findings::Median.of(values)
      end

      # The first sample of the first run of PERSISTENCE_RUN consecutive own samples at the
      # line; a sample that does not carry the share as a number breaks the run.
      def first_epoch(key)
        run = []
        @samples.each do |epoch, values|
          run = present?(values[key]) ? [*run, epoch] : []
          return run.first if run.size >= PERSISTENCE_RUN
        end
        nil
      end

      def present?(share) = share.is_a?(Numeric) && share >= TASK_PRESENT_SHARE

      # The commonest `dominant_logic_tasks` mask of the last decile, the smaller on a tie.
      def dominant_tasks
        tally = numbers(DOMINANT_TASKS_KEY).tally
        tally.min_by { |mask, count| [-count, mask] }&.first
      end
    end
  end
end
