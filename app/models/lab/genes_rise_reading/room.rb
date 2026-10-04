# frozen_string_literal: true

module Lab
  module GenesRiseReading
    # H-room's reading of one child: its gain in `logic_depth_classes` over the final quarter
    # of its settled samples (cut by index, as Series cuts it), the lower median of the
    # quarter's last ROOM_WINDOW samples minus that of its first ROOM_WINDOW. A window with
    # fewer than MIN_DECILE_SAMPLES numbers leaves the gain unread.
    class Room
      Reading = Data.define(:first, :last) do
        def measured? = !first.nil? && !last.nil?

        def gain = measured? ? last - first : nil
      end

      def self.read(samples, parent_epoch:)
        settled = samples.select { |epoch, _| epoch > parent_epoch + SETTLING_WINDOW }
        quarter = settled.drop((settled.size * FINAL_QUARTER).floor)
        Reading.new(first: median(quarter.first(ROOM_WINDOW)), last: median(quarter.last(ROOM_WINDOW)))
      end

      def self.median(samples)
        values = samples.filter_map { |_, values| values[CLASSES_KEY] if values[CLASSES_KEY].is_a?(Numeric) }
        values.size < MIN_DECILE_SAMPLES ? nil : Findings::Median.of(values)
      end
      private_class_method :median
    end
  end
end
