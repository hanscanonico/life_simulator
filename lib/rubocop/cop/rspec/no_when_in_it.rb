# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Enforces that `it` descriptions do not contain the word "when".
      # Use a `context` block for conditional descriptions instead.
      #
      # @example
      #   # bad
      #   it "returns nil when category is all" do ...
      #
      #   # good
      #   context "when category is all" do
      #     it "returns nil" do ...
      #   end
      class NoWhenInIt < Base
        extend AutoCorrector

        MSG = 'Avoid "when" in `it` description. Use a `context` block instead.'

        RESTRICT_ON_SEND = %i[it].freeze

        WHEN_PATTERN = /\bwhen\b/i

        def on_send(node)
          description = node.first_argument
          return unless description&.str_type?
          return unless description.value.match?(WHEN_PATTERN)

          add_offense(description) do |corrector|
            autocorrect(corrector, node, description)
          end
        end

        private

        def autocorrect(corrector, send_node, description)
          match = description.value.match(WHEN_PATTERN)
          prefix = description.value[0...match.begin(0)].strip
          when_clause = description.value[match.begin(0)..].strip
          # Without a leading description there is nothing to keep on `it`.
          return if prefix.empty?

          quote = description.source[0]
          target = send_node.block_node || send_node
          indent = " " * target.loc.column

          it_source = target.source.sub(description.source, "#{quote}#{prefix}#{quote}")
          indented_it = it_source.gsub("\n", "\n  ")

          corrector.replace(
            target,
            "context #{quote}#{when_clause}#{quote} do\n" \
            "#{indent}  #{indented_it}\n" \
            "#{indent}end"
          )
        end
      end
    end
  end
end
