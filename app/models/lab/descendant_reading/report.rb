# frozen_string_literal: true

require "csv"

module Lab
  module DescendantReading
    # The from-emerged sweep's reading, as Experiments::FromEmergedReadingService assembles
    # it: the per-child table, the per-treatment counts, the paired comparisons with each
    # parent's agreement, and H-persistence — interim until `final`.
    Report = Data.define(:children, :arms, :comparisons, :persistence, :final) do
      def interim? = !final

      delegate :any?, to: :children

      def trajectory_chart
        lines = arms.map { |arm| Charts::ArmLines::Arm.new(label: arm.name, points: arm.trajectory) }
        Charts::ArmLines.new(arms: lines, y_label: "replicator_share",
                             title: "Median replicator share per #{TRAJECTORY_BIN} epochs past the parent, " \
                                    "per treatment")
      end

      def to_text
        [heading, table(CHILD_COLUMNS, children.map(&:cells)), table(ARM_COLUMNS, arms.map(&:cells)),
         table(COMPARISON_COLUMNS, comparison_cells), table(AGREEMENT_COLUMNS, agreement_cells),
         persistence_line].join("\n")
      end

      def to_csv
        CSV.generate do |csv|
          csv << [heading]
          [[CHILD_COLUMNS, children.map(&:cells)], [ARM_COLUMNS, arms.map(&:cells)],
           [COMPARISON_COLUMNS, comparison_cells], [AGREEMENT_COLUMNS, agreement_cells]].each do |columns, rows|
            csv << []
            csv << columns
            rows.each { |row| csv << row }
          end
          csv << []
          csv << [persistence_line]
        end
      end

      def heading = final ? "final reading" : "interim reading: not every child of every qualifying parent is terminal"

      def persistence_line
        relapsed = persistence.relapsed.size
        line = "H-persistence #{persistence.outcome_label}: #{relapsed} of " \
               "#{persistence.children.size} continuation children relapsed"
        return line if relapsed.positive? || !final

        "#{line}; the colonies persisted over the budget and the constant-hazard hypothesis had no relapse " \
          "to be read on"
      end

      private

      def comparison_cells
        comparisons.map do |treatment, comparison|
          [treatment.hypothesis, treatment.name, comparison.measured_count, comparison.favouring, comparison.against,
           comparison.ties, comparison.p_value&.to_f, comparison.outcome_label, comparison.reading_label,
           comparison.carried_by.map { |parents| parents.join("+") }.join(" ").presence]
        end
      end

      def agreement_cells
        comparisons.flat_map do |treatment, comparison|
          comparison.agreement.map do |row|
            [treatment.name, row.parent_id, row.treatment, row.continuation, row.ties, row.unmeasured]
          end
        end
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
