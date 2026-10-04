# frozen_string_literal: true

require "csv"

module Lab
  module GenesRiseReading
    # The genes-rise sweep's reading, as Experiments::GenesRiseReadingService assembles it: the
    # per-child table, the per-arm counts, the five tests with each parent's agreement, and
    # beside them their extinct-kept reading (`kept_tests`); interim until `final`.
    # `minima_read` says whether the offline minimum was handed in, without which H-driven
    # reads no measured pairs.
    Report = Data.define(:children, :arms, :tests, :kept_tests, :minima_read, :final) do
      delegate :any?, to: :children

      def interim? = !final

      # Each test beside its extinct-kept reading.
      def readings = tests.zip(kept_tests)

      def heading
        state = if !any? then "no child yet"
                elsif final then "final"
                else "interim: not every child of every qualifying parent has finished"
                end
        minima = minima_read ? "" : "; H-driven awaits the offline minimum"
        "genes-rise reading, #{state}#{minima} (Genes rise: #{LABEL})"
      end

      def to_text
        [heading, *(any? ? tables.map { |columns, rows| TextTable.render(columns, rows) } : [])].join("\n")
      end

      def to_csv
        CSV.generate do |csv|
          csv << [heading]
          next unless any?

          tables.each do |columns, rows|
            csv << []
            csv << columns
            rows.each { |row| csv << row }
          end
        end
      end

      private

      def tables
        [[CHILD_COLUMNS, children.map(&:cells)], [ARM_COLUMNS, arms.map(&:cells)],
         [TEST_COLUMNS, tests.map(&:cells)], [TEST_COLUMNS, kept_tests.map(&:cells)],
         [AGREEMENT_COLUMNS, tests.flat_map(&:agreement_cells)]]
      end
    end
  end
end
