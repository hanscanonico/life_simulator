# frozen_string_literal: true

module Stats
  # The one-sided exact sign test over discordant pairs: the chance, under a fair coin, of
  # at least `favouring` of the `favouring + against` pairs going the tested way. Ties are
  # not pairs here. The tail is an exact rational, so a p-value at a boundary is compared
  # against its threshold exactly.
  module SignTest
    # Nil with no discordant pair: nothing was tested.
    def self.one_sided(favouring:, against:)
      trials = favouring + against
      return nil if trials.zero?

      tail = (favouring..trials).sum { |count| choose(trials, count) }
      Rational(tail, 2**trials)
    end

    def self.choose(outer, inner) = (0...inner).reduce(1) { |product, step| product * (outer - step) / (step + 1) }
  end
end
