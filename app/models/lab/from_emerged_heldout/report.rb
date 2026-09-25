# frozen_string_literal: true

require "csv"

module Lab
  module FromEmergedHeldout
    # The held-out confirmatory reading, as Experiments::FromEmergedReadingService assembles
    # it beside the original one: the held-out children, their counts per treatment and the
    # two tests per economy arm. Whether it is final is the sweep's, passed in: every child of
    # every qualifying parent finished.
    Report = Data.define(:children, :arms, :tests) do
      delegate :any?, to: :children

      def heading(final:)
        return "held-out reading: no held-out child yet" unless any?

        final ? "held-out reading, final" : "held-out reading, interim: not every held-out child has finished"
      end

      def to_text(final:)
        [heading(final: final), *(any? ? tables.map { |columns, rows| table(columns, rows) } : [])].join("\n")
      end

      def to_csv(final:)
        CSV.generate do |csv|
          csv << [heading(final: final)]
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
        [[CHILD_COLUMNS, children.map { |child| child_cells(child) }], [ARM_COLUMNS, arms.map(&:cells)],
         [TEST_COLUMNS, tests.map(&:cells)], [AGREEMENT_COLUMNS, tests.flat_map(&:agreement_cells)]]
      end

      def child_cells(child)
        heldout = child.heldout
        [child.run_id, child.parent_id, child.seed, child.treatment.name, child.status, heldout.settled_relapse_epoch,
         heldout.extinct, heldout.first_latency, heldout.last_latency, heldout.latency_ratio&.to_f,
         heldout.survivor?, child.reading.complexity]
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
