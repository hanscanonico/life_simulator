# frozen_string_literal: true

require "csv"

module Lab
  module MetaStackReading
    # The meta-stack sweep's reading, as Experiments::MetaStackReadingService assembles it:
    # the per-child table over its three arms and the logic sweep's twins, the per-arm counts,
    # the six tests with each parent's agreement, their two sensitivity readings (the extinct
    # pairs kept, `kept_tests`, and the piloted parents left out, `unpiloted_tests`) and the
    # pairs by (parent, seed); interim until `final`, when this sweep and the logic sweep have
    # both settled.
    Report = Data.define(:children, :arms, :tests, :kept_tests, :unpiloted_tests, :final) do
      delegate :any?, to: :children

      def interim? = !final

      # Every (parent, seed) any arm holds, in order, beside its child in each arm, nil where
      # that child does not exist yet.
      def pairs
        by_arm = arms.map { |arm| arm.children.index_by { |child| [child.parent_id, child.seed] } }
        by_arm.flat_map(&:keys).uniq.sort.map { |key| [*key, *by_arm.map { |children| children[key] }] }
      end

      # Each test beside its two sensitivity readings.
      def readings = tests.zip(kept_tests, unpiloted_tests)

      def heading
        state = if !any? then "no child yet"
                elsif final then "final"
                else "interim: not every child of every qualifying parent has finished, here and in the logic sweep"
                end
        "meta-stack reading, #{state} (#{LABEL})"
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
         [TEST_COLUMNS, unpiloted_tests.map(&:cells)], [AGREEMENT_COLUMNS, tests.flat_map(&:agreement_cells)],
         [PAIR_COLUMNS, pairs.map { |parent_id, seed, *twins| [parent_id, seed, *twins.flat_map { pair_cells(_1) }] }]]
      end

      def pair_cells(child)
        return [nil, nil, nil] if child.nil?

        [child.run_id, child.capability(DEEP_CAPABILITY_KEY), child.reading.last_share]
      end
    end
  end
end
