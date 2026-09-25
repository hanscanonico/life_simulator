# frozen_string_literal: true

module Lab
  module LineageDiversityReading
    # One radius of the sweep and its runs (Experiments::LineageDiversityReadingService::RunRow),
    # beside the radius sweep's emergence count at the same radius, `radius_emerged` of
    # `radius_finished` finished runs. That comparison is descriptive and is not a
    # replication: the rate, the seeds and the lineage rule all differ.
    Arm = Data.define(:radius, :rows, :radius_emerged, :radius_finished) do
      def self.label_of(radius) = radius.zero? ? "well-mixed" : "radius #{radius}"

      def label = self.class.label_of(radius)

      def finished = rows.select(&:finished?)

      def emerged = finished.select { |row| row.reading.emerged? }

      def measured = emerged.select { |row| row.reading.measured? }

      def verdict_count(verdict) = emerged.count { |row| row.reading.verdict == verdict }

      def read? = measured.size >= MIN_ARM_RUNS

      def values = measured.map { |row| row.reading.effective_count }

      def effective_count = Findings::Median.of(values)

      # The median over the measured runs of each run's last-decile median of `key`.
      def descriptive(key) = Findings::Median.of(measured.filter_map { |row| row.reading.descriptive_value(key) })

      def copy_latency_first = Findings::Median.of(measured.filter_map { |row| row.reading.copy_latency_first })

      def cells
        [label, rows.size, finished.size, emerged.size, measured.size,
         *VERDICTS.map { |verdict| verdict_count(verdict) }, effective_count, read? ? "read" : "unread",
         *DESCRIPTIVE_KEYS.map { |key| descriptive(key) }, copy_latency_first, radius_emerged, radius_finished]
      end
    end
  end
end
