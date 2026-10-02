# frozen_string_literal: true

module Lab
  module ToplessRiseReading
    # One child's own samples — `[[epoch, values], ...]` above its parent epoch, in epoch
    # order — read for the rise rule. Past the settling window a decile is cut by index over
    # all settled samples, unfiltered, and inside it the samples that carry
    # `logic_depth_max` as a number count, −1 among them; its median is
    # Findings::Median's lower middle, and fewer than MIN_DECILE_SAMPLES numbers leave it
    # unread. The depths' first epochs are descriptive, read over every own sample under the
    # persistence rule.
    #
    # The bar a late rise must clear is the deepest the lineage reached before the second
    # half: the parent's depth at descent (the first own sample), every depth held under the
    # persistence rule up to the fifth decile's end, and the fifth-decile median. Re-climbing
    # to the parent's own depth after the switch to the four-input ladder is no rise.
    class Child
      Reading = Data.define(:fifth_depth, :last_depth, :descent_depth, :first_half_held, :first_epochs,
                            :late_epoch, :last_classes, :reached_floor) do
        # Both deciles carry a median.
        def measured? = !fifth_depth.nil? && !last_depth.nil?

        def bar = [fifth_depth, descent_depth, first_half_held].compact.max

        # The lineage already stood at the deepest depth a reading can show before the second
        # half: read as no rise.
        def ceilinged? = measured? && bar >= CEILING_DEPTH

        def rises? = measured? && !ceilinged? && last_depth >= bar + RISE_STEP

        # The deepest depth held for PERSISTENCE_RUN samples running, −1 where none was, and
        # the first epoch it was.
        def deepest_held = first_epochs.keys.max || NOTHING_HELD

        def deepest_held_epoch = first_epochs[deepest_held]

        # The depths first held, under the persistence rule, in the second half of the settled
        # samples: the repeated, late steps the study's §2.4 reads "keeps rising" as.
        def late_depths
          return [] if late_epoch.nil?

          first_epochs.select { |_, epoch| epoch >= late_epoch }.keys.sort
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
        Reading.new(fifth_depth: median(decile(RISE_DECILE), DEPTH_KEY), last_depth: median(decile(DECILES), DEPTH_KEY),
                    descent_depth: descent_depth, first_half_held: first_epochs(first_half).keys.max,
                    first_epochs: first_epochs(@samples), late_epoch: late_epoch,
                    last_classes: median(decile(DECILES), CLASSES_KEY),
                    reached_floor: depths(@samples).any? { |depth| depth >= CEILING_DEPTH })
      end

      private

      def late_epoch = decile(RISE_DECILE + 1).first&.first

      def descent_depth
        value = @samples.first&.last&.fetch(DEPTH_KEY, nil)
        value if value.is_a?(Numeric)
      end

      # The own samples up to the fifth decile's end, settling window included.
      def first_half = late_epoch.nil? ? @samples : @samples.take_while { |epoch, _| epoch < late_epoch }

      def decile(index)
        size = @settled.size
        @settled[((index - 1) * size / DECILES)...(index * size / DECILES)]
      end

      def numbers(samples, key) = samples.filter_map { |_, values| values[key] if values[key].is_a?(Numeric) }

      def depths(samples) = numbers(samples, DEPTH_KEY)

      def median(samples, key)
        values = numbers(samples, key)
        values.size < MIN_DECILE_SAMPLES ? nil : Findings::Median.of(values)
      end

      # Each depth from 0 up to the deepest ever read, against the first sample of the first
      # run of PERSISTENCE_RUN consecutive own samples at it or deeper; a sample that does not
      # carry the depth as a number breaks the run. Depths never held so are left out.
      def first_epochs(samples)
        (0..(depths(samples).max || NOTHING_HELD)).each_with_object({}) do |depth, epochs|
          epoch = first_epoch_at(samples, depth)
          epochs[depth] = epoch unless epoch.nil?
        end
      end

      def first_epoch_at(samples, depth)
        run = []
        samples.each do |epoch, values|
          value = values[DEPTH_KEY]
          run = value.is_a?(Numeric) && value >= depth ? [*run, epoch] : []
          return run.first if run.size >= PERSISTENCE_RUN
        end
        nil
      end
    end
  end
end
