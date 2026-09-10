# frozen_string_literal: true

module Lab
  # The engine's parameter schema (`runner schema`, refreshed by `make schema` into
  # config/engine_schema.json), read-only. Defaults and ranges live in the engine's
  # `Params` and nowhere else; a Rust test fails the gate when the committed copy drifts.
  module Schema
    PATH = Rails.root.join("config/engine_schema.json")

    # Parameters a run never carries: the substrate belongs to the experiment, and the two
    # sampling cadences are the runner's business. Leaving them out of `runs.params` lets
    # the engine's own defaults apply.
    NON_RUN_PARAMS = %w[substrate sample_every snapshot_every].freeze

    class << self
      def fields
        @fields ||= document.fetch("fields").freeze
      end

      # The transition rule the engine's tracker measures by: `threshold` on
      # `compress_ratio` and the `hold_samples` further samples it must stay below it.
      def transition
        @transition ||= document.fetch("transition").freeze
      end

      def defaults
        @defaults ||= fields.to_h { |field| [field["name"], field["default"]] }.freeze
      end

      # The defaults a sweep starts from before its grid is merged in.
      def run_defaults
        @run_defaults ||= defaults.except(*NON_RUN_PARAMS).freeze
      end

      def param?(name)
        defaults.key?(name)
      end

      def values_for(name)
        field(name)["values"] || []
      end

      def field(name)
        fields.find { |candidate| candidate["name"] == name } ||
          raise(ArgumentError, "the engine schema has no #{name} parameter")
      end

      private

      def document
        @document ||= JSON.parse(PATH.read).freeze
      end
    end
  end
end
