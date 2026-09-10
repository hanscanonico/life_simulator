# frozen_string_literal: true

module Lab
  # The engine's parameter schema (`runner schema`, refreshed by `make schema` into
  # config/engine_schema.json), read-only. Defaults and ranges live in the engine's
  # `Params` and nowhere else; a Rust test fails the gate when the committed copy drifts.
  module Schema
    PATH = Rails.root.join("config/engine_schema.json")

    class << self
      def fields
        @fields ||= JSON.parse(PATH.read).fetch("fields").freeze
      end

      def defaults
        @defaults ||= fields.to_h { |field| [field["name"], field["default"]] }.freeze
      end

      def values_for(name)
        field(name)["values"] || []
      end

      def field(name)
        fields.find { |candidate| candidate["name"] == name } ||
          raise(ArgumentError, "the engine schema has no #{name} parameter")
      end
    end
  end
end
