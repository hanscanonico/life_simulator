# frozen_string_literal: true

require "csv"

module Lab
  module OutComputeReading
    # The out-compute sweep's reading, as Experiments::OutComputeReadingService assembles it:
    # the per-child table, the per-arm counts, the five tests with each parent's agreement, and
    # beside them their sensitivity readings (the extinct pairs kept, `kept_tests`, and the
    # piloted parents left out, `unpiloted_tests`); interim until `final`.
    Report = Data.define(:children, :arms, :tests, :kept_tests, :unpiloted_tests, :final) do
      delegate :any?, to: :children

      def interim? = !final

      # Each test beside its extinct-kept and its unpiloted reading.
      def readings = tests.zip(kept_tests, unpiloted_tests)

      def heading
        state = if !any? then "no child yet"
                elsif final then "final"
                else "interim: not every child of every qualifying parent has finished"
                end
        "out-compute reading, #{state} (Out-compute: #{LABEL})"
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
         [TEST_COLUMNS, unpiloted_tests.map(&:cells)], [AGREEMENT_COLUMNS, tests.flat_map(&:agreement_cells)]]
      end
    end
  end
end
