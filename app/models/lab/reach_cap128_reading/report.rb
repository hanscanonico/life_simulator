# frozen_string_literal: true

require "csv"

module Lab
  module ReachCap128Reading
    # The reach-cap128 sweep's reading, as Experiments::ReachCap128ReadingService assembles
    # it: the per-run table, the two arms and H-reach128 — interim until `final`.
    Report = Data.define(:rows, :arms, :comparison, :final) do
      def interim? = !final

      def heading
        return "final reading" if final

        "interim reading: not every run has finished and had every world it kept read"
      end

      def to_text
        [heading, table(RUN_COLUMNS, rows.map(&:cells)), table(ARM_COLUMNS, arms.map(&:cells)), comparison.line]
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
          csv << [comparison.line]
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
