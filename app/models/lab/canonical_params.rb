# frozen_string_literal: true

module Lab
  # The identity of a run inside its experiment is (canonical params, seed). Canonical
  # means: the engine's run defaults filled in for the keys a run stored before the schema
  # grew them (a run seeded before `ops` existed ran with the engine's `ops` default), keys
  # sorted, and every number carried as a Rational so 0 and 0.0 — the same arm on both
  # sides of a jsonb round trip — hash and compare as one value.
  module CanonicalParams
    NUMERIC_ARGUMENT = /\A[-+]?\d+(\.\d+)?([eE][-+]?\d+)?\z/

    class << self
      def for(params)
        resolve(params).transform_values { |value| normalise(value) }
      end

      def resolve(params)
        Schema.run_defaults.merge(params.to_h.transform_keys(&:to_s)).sort.to_h
      end

      def normalise(value)
        value.is_a?(Numeric) ? value.to_r : value
      end

      # A rake argument only ever arrives as a string: "64" must match the stored 64,
      # "0.0" the stored 0.0, and "<>{}+-.,[]" the stored instruction set.
      def same_value?(stored, argument)
        text = argument.to_s
        return normalise(stored) == Float(text).to_r if stored.is_a?(Numeric) && NUMERIC_ARGUMENT.match?(text)

        stored.to_s == text
      end
    end
  end
end
