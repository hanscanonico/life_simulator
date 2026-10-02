# frozen_string_literal: true

require "csv"

module Lab
  module ToplessRiseReading
    # The topless-rise sweep's reading, as Experiments::ToplessRiseReadingService assembles
    # it: the per-child table, the per-arm counts, the two tests with each parent's agreement,
    # and beside them their extinct-kept reading (`kept_tests`) and their re-reading on the
    # deep parents' children alone (`deep_tests`); interim until `final`.
    Report = Data.define(:children, :arms, :tests, :kept_tests, :deep_tests, :final) do
      delegate :any?, to: :children

      def interim? = !final

      # Each test beside its two other readings.
      def readings = tests.zip(kept_tests, deep_tests)

      # The children already at the ceiling by their fifth decile, printed apart.
      def ceilinged = children.select(&:ceilinged?)

      # More than half of the rise arm's children with both deciles read are ceilinged: the
      # ladder had a near top after all, and the tests are not read as an answer.
      def mostly_ceilinged?
        read = arms.find { |arm| arm.treatment.key == :rise }.children.select { |child| child.depth.measured? }
        read.any? && read.count(&:ceilinged?) * 2 > read.size
      end

      def heading
        state = if !any? then "no child yet"
                elsif final then "final"
                else "interim: not every child of every qualifying parent has finished"
                end
        ceiling = mostly_ceilinged? ? "; most rise children ceilinged, the tests are not an answer" : ""
        "topless-rise reading, #{state}#{ceiling} (#{LABEL})"
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
         [TEST_COLUMNS, deep_tests.map(&:cells)], [AGREEMENT_COLUMNS, tests.flat_map(&:agreement_cells)],
         [CHILD_COLUMNS, ceilinged.map(&:cells)]]
      end
    end
  end
end
