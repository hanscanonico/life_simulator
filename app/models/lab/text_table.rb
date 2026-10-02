# frozen_string_literal: true

module Lab
  # A reading's table as `lab:*_report` prints it: right-aligned columns, a dash for a
  # missing value, floats as the charts format them, and underscores read as spaces.
  module TextTable
    def self.render(columns, rows)
      lines = [columns, *rows.map { |row| row.map { |cell| format_cell(cell) } }]
      widths = lines.transpose.map { |column| column.map(&:length).max }

      lines.map { |line| "#{line.each_with_index.map { |cell, index| cell.rjust(widths[index]) }.join('  ')}\n" }.join
    end

    def self.format_cell(cell)
      return "—" if cell.nil?
      return Charts.format_value(cell) if cell.is_a?(Float)

      cell.to_s.tr("_", " ")
    end
  end
end
