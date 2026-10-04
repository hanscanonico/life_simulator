# frozen_string_literal: true

module Lab
  module GenesRiseReading
    # One child's own samples — `[[epoch, values], ...]` above its parent epoch, in epoch
    # order — read on one key for a late rise. The rise rule is topless-rise's, unchanged and
    # with no ceiling (Lab::ToplessRiseReading::Child): deciles cut by index over the settled
    # samples, lower-middle medians, and the bar from the fifth decile, the value at descent
    # and every value held for PERSISTENCE_RUN samples running up to the fifth decile's end.
    #
    # On top of it, the study's §5.1 clause 4: the values above the one at descent first held
    # under the persistence rule are the persistent new maxima, one per distinct first epoch
    # (a jump that takes several values at once is one maximum), and the last must fall in the
    # final quarter of the settled samples, cut by index as the deciles are. And a magnitude:
    # the last-decile median at least MAGNITUDE times the bar, which a creep of a few values at
    # a reached cap does not clear.
    class Series
      Reading = Data.define(:rise, :maxima, :final_quarter_epoch) do
        delegate :measured?, :bar, :descent_depth, :rises?, to: :rise

        def last = rise.last_depth

        def last_maximum_epoch = maxima.last

        # At least MAXIMA_NEEDED persistent new maxima, the last in the final quarter.
        def sustained?
          !final_quarter_epoch.nil? && maxima.size >= MAXIMA_NEEDED && last_maximum_epoch >= final_quarter_epoch
        end

        def large? = measured? && last >= bar * MAGNITUDE

        def late_rise? = rises? && sustained? && large?
      end

      def self.read(samples, parent_epoch:, key:)
        new(samples, parent_epoch: parent_epoch, key: key).reading
      end

      def initialize(samples, parent_epoch:, key:)
        @samples = samples
        @parent_epoch = parent_epoch
        @key = key
      end

      def reading
        rise = ToplessRiseReading::Child.read(@samples, parent_epoch: @parent_epoch, key: @key, ceiling: nil)
        floor = rise.descent_depth || ToplessRiseReading::NOTHING_HELD
        maxima = rise.first_epochs.select { |value, _| value > floor }.values.uniq.sort
        Reading.new(rise: rise, maxima: maxima, final_quarter_epoch: final_quarter_epoch)
      end

      private

      def final_quarter_epoch
        settled = @samples.select { |epoch, _| epoch > @parent_epoch + SETTLING_WINDOW }
        settled[(settled.size * FINAL_QUARTER).floor]&.first
      end
    end
  end
end
