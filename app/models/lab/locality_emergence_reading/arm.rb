# frozen_string_literal: true

module Lab
  module LocalityEmergenceReading
    # One radius of the sweep and its runs (Experiments::LocalityEmergenceReadingService::RunRow).
    # Only a finished run is counted in the rate: a run still under way may yet emerge.
    Arm = Data.define(:radius, :rows) do
      def self.label_of(radius) = radius == WELL_MIXED ? "well-mixed" : "radius #{radius}"

      def label = self.class.label_of(radius)

      def finished = rows.count(&:finished?)

      def emerged = rows.count(&:emerged)

      def finished? = finished.positive?

      # An exact rational, so two arms' rates compare exactly; nil before any run finished.
      def rate = finished? ? Rational(emerged, finished) : nil

      def cells = [label, rows.size, finished, emerged, rate&.to_f]
    end
  end
end
