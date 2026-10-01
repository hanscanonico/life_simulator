# frozen_string_literal: true

module Lab
  module MetabolismReading
    # One child's own samples — `[[epoch, values], ...]` above its parent epoch, in epoch
    # order — read for what the metabolism entry adds to the from-emerged rules. The tests'
    # values are read past the settling window: the last decile is the last `ceil(n / 10)`
    # of all `n` settled samples, unfiltered, and inside it the samples that carry the key
    # as a number, their median Findings::Median's lower middle. The ladder's first epochs
    # are descriptive and read every own sample, the window included.
    class Child
      Reading = Data.define(:capabilities, :first_epochs, :dominant_tasks) do
        # The last-decile median of `task_capability` or `task_capability_loop`; nil where
        # the decile holds fewer than MIN_DECILE_SAMPLES of them.
        def capability(key) = capabilities[key]

        # The first own epoch any loop rung reached TASK_PRESENT_SHARE; nil if none did.
        def loop_epoch = first_epochs.values_at(*LOOP_TASKS).compact.min

        def climbed_loop? = !loop_epoch.nil?

        # A loop rung arose where INC or DEC had already reached the line, at or before it.
        def stepping_stone?
          climbed_loop? && first_epochs.values_at(*STEPPING_STONES).compact.any? { |epoch| epoch <= loop_epoch }
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
        Reading.new(capabilities: [CAPABILITY_KEY, LOOP_CAPABILITY_KEY].index_with { |key| capability(key) },
                    first_epochs: TASKS.index_with { |task| first_epoch(MetabolismReading.share_key(task)) },
                    dominant_tasks: dominant_tasks)
      end

      private

      def last_decile = @settled.last((@settled.size + 9) / 10)

      def numbers(key) = last_decile.filter_map { |_, values| values[key] if values[key].is_a?(Numeric) }

      def capability(key)
        values = numbers(key)
        values.size < MIN_DECILE_SAMPLES ? nil : Findings::Median.of(values)
      end

      def first_epoch(key)
        @samples.find { |_, values| values[key].is_a?(Numeric) && values[key] >= TASK_PRESENT_SHARE }&.first
      end

      # The commonest `dominant_tasks` mask of the last decile, the smaller mask on a tie.
      def dominant_tasks
        tally = numbers(DOMINANT_TASKS_KEY).tally
        tally.min_by { |mask, count| [-count, mask] }&.first
      end
    end
  end
end
