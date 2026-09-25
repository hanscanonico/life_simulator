# frozen_string_literal: true

require "csv"

module Lab
  module LineageDiversityReading
    # The lineage-diversity sweep's reading, as Experiments::LineageDiversityReadingService
    # assembles it: the per-run table, the per-arm counts and the hypothesis — interim until
    # `final`.
    Report = Data.define(:rows, :arms, :hypothesis, :final) do
      def interim? = !final

      def heading = final ? "final reading" : "interim reading: not every run of the sweep has finished"

      def to_text
        [heading, table(RUN_COLUMNS, rows.map(&:cells)), table(ARM_COLUMNS, arms.map(&:cells)), hypothesis.line]
          .join("\n")
      end

      def to_csv
        CSV.generate do |csv|
          csv << [heading]
          [[RUN_COLUMNS, rows.map(&:cells)], [ARM_COLUMNS, arms.map(&:cells)]].each do |columns, cells|
            csv << []
            csv << columns
            cells.each { |row| csv << row }
          end
          csv << []
          csv << [hypothesis.line]
        end
      end

      private

      def table(columns, cells)
        lines = [columns, *cells.map { |row| row.map { |cell| format_cell(cell) } }]
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
