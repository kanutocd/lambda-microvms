# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Internal adapter implementations for provider-specific SDK surfaces.
    module Adapters
      # Adapter for the experimental Lambda MicroVM SDK operation surface.
      class MicroVMSdk
        # SDK method names required by the experimental MicroVM lifecycle wrapper.
        REQUIRED_OPERATIONS = %i[
          create_microvm_image
          get_microvm_image
          delete_microvm_image
          run_microvm
          get_microvm
          list_microvms
          suspend_microvm
          resume_microvm
          terminate_microvm
          create_microvm_auth_token
        ].freeze

        attr_reader :sdk

        def initialize(sdk)
          @sdk = sdk
        end

        # Return MicroVM SDK operations missing from the wrapped SDK client.
        #
        # @return [Array<Symbol>] missing SDK operation names
        def unsupported_operations
          REQUIRED_OPERATIONS.reject { |operation| sdk.respond_to?(operation) }
        end

        # Check whether the wrapped SDK client exposes all MicroVM operations.
        #
        # @return [Boolean]
        def supported?
          unsupported_operations.empty?
        end

        # Dispatch a MicroVM operation to the wrapped SDK client.
        #
        # @param operation [Symbol] SDK method name
        # @param params [Hash] SDK request parameters
        # @return [Object] raw SDK response
        # @raise [UnsupportedOperationError] when the SDK does not expose the operation
        def call(operation, **params)
          unless sdk.respond_to?(operation)
            raise UnsupportedOperationError, "Aws::Lambda::Client does not expose ##{operation}; run sdk-contract"
          end

          sdk.public_send(operation, **params)
        end
      end
    end
  end
end
