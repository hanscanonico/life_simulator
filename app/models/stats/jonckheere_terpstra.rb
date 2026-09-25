# frozen_string_literal: true

module Stats
  # The one-sided Jonckheere–Terpstra test for a trend across ordered groups, with a
  # permutation p rather than the normal approximation, which is anti-conservative at a few
  # values a group (`docs/design_record.md`, 2026-09-25, "Lineage diversity after a
  # transition").
  #
  # `groups` are arrays of numbers in the order the trend predicts them to rise. The
  # statistic counts, over every pair of values in two different groups, the pairs where the
  # value of the later group is the higher, a tie counting one half. The p is (1 + b) /
  # (1 + permutations), where b of `permutations` dealings reach a statistic at least the
  # observed one. A dealing deals the pooled values at random into groups of the observed
  # sizes: it shuffles, with `random`, the observed sizes' group labels over the pooled
  # values in ascending order.
  class JonckheereTerpstra
    def initialize(groups)
      @sizes = groups.map(&:size)
      labelled = groups.each_with_index.flat_map { |values, group| values.map { |value| [value, group] } }
                       .sort_by(&:first)
      @pooled = labelled.map(&:first)
      @observed = twice_statistic(labelled.map(&:last))
    end

    def statistic = Rational(@observed, 2)

    def p_value(permutations:, random:)
      labels = @sizes.each_with_index.flat_map { |size, group| [group] * size }
      reached = Array.new(permutations).count { twice_statistic(labels.shuffle(random: random)) >= @observed }
      Rational(1 + reached, 1 + permutations)
    end

    private

    # Twice the statistic, so a tie's half stays an integer. `labels` are the groups of the
    # pooled values in ascending order. A value earns two for each lower value of an earlier
    # group, and each pair tied across two groups earns one. `earlier[group]` counts the
    # values below the current tie in the groups before `group`.
    def twice_statistic(labels)
      earlier = Array.new(@sizes.size, 0)
      tie_runs.sum do |run|
        run_labels = run.map { |index| labels[index] }
        total = run_labels.sum { |group| 2 * earlier[group] } + tied_pairs(run_labels)
        run_labels.each { |group| (group + 1).upto(@sizes.size - 1) { |later| earlier[later] += 1 } }
        total
      end
    end

    def tied_pairs(run_labels)
      return 0 if run_labels.size == 1

      ((run_labels.size**2) - run_labels.tally.values.sum { |count| count**2 }) / 2
    end

    # The pooled positions, gathered by tied value.
    def tie_runs = @tie_runs ||= (0...@pooled.size).chunk_while { |left, right| @pooled[left] == @pooled[right] }.to_a
  end
end
