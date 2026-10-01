# frozen_string_literal: true

require "csv"

module Lab
  module MetabolismReading
    # The metabolism sweep's reading, as Experiments::MetabolismReadingService assembles it:
    # the per-child table, the per-arm counts, the three tests with each parent's agreement,
    # interim until `final` (Experiments::DescendantSweepSettledService).
    Report = Data.define(:children, :arms, :tests, :final) do
      delegate :any?, to: :children

      def interim? = !final

      def heading
        state = if !any? then "no child yet"
                elsif final then "final"
                else "interim: not every child of every qualifying parent has finished"
                end
        "metabolism reading, #{state} (#{LABEL})"
      end

      def to_text
        [heading, *(any? ? tables.map { |columns, rows| table(columns, rows) } : [])].join("\n")
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
         [TEST_COLUMNS, tests.map(&:cells)], [AGREEMENT_COLUMNS, tests.flat_map(&:agreement_cells)]]
      end

      def table(columns, rows)
        lines = [columns, *rows.map { |row| row.map { |cell| format_cell(cell) } }]
        widths = lines.transpose.map { |column| column.map(&:length).max }

        lines.map { |line| "#{line.each_with_index.map { |cell, index| cell.rjust(widths[index]) }.join('  ')}\n" }
             .join
      end

      def format_cell(cell)
        return "—" if cell.nil?
        return Charts.format_value(cell) if cell.is_a?(Float)

        cell.to_s.tr("_", " ")
      end
    end
  end
end
