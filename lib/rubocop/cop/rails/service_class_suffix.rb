# frozen_string_literal: true

module RuboCop
  module Cop
    module Rails
      # Enforces that service classes which include Callable end in `Service`.
      #
      # @example
      #   # bad
      #   class EmaCalculator
      #     include Callable
      #   end
      #
      #   # good
      #   class EmaCalculatorService
      #     include Callable
      #   end
      class ServiceClassSuffix < Base
        MSG = "Service class including Callable must end in `Service`."

        def on_class(node)
          class_name = node.identifier.const_name
          return if class_name.end_with?("Service")
          return unless includes_callable?(node.body)

          add_offense(node.identifier)
        end

        private

        def includes_callable?(body)
          return false if body.nil?

          body.each_descendant(:send).any? do |send_node|
            send_node.method_name == :include &&
              send_node.first_argument&.const_type? &&
              send_node.first_argument.const_name&.end_with?("Callable")
          end
        end
      end
    end
  end
end
