# frozen_string_literal: true

module Runs
  class Persistence
    # What a run whose samples have not been summarised answers: every reading absent and
    # no outcome either way, so a caller reads a summary without asking whether it has one.
    class Missing
      def summarised? = false

      def relapsed? = false

      def persisted? = false

      def counted? = false

      def sampled? = false

      def census_peak = nil

      def peak_epoch = nil

      def epochs_persisted = nil

      def census_label = "—"

      def compact_census_label = "—"
    end
  end
end
