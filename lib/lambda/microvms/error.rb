# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Base error for lambda-microvms.
    class Error < StandardError; end

    # Raised when an expected MicroVM lifecycle state is not reached in time.
    class WaitTimeoutError < Error; end

    # Raised when the configured AWS Lambda SDK client does not expose a needed operation.
    class UnsupportedOperationError < Error; end

    # Raised when project configuration is invalid or incomplete.
    class ConfigurationError < Error; end

    # Raised when an external command such as Docker fails.
    class CommandError < Error; end

    # Raised when a MicroVM endpoint call fails with a non-success response.
    class EndpointError < Error
      attr_reader :status, :body

      def initialize(message, status:, body:)
        @status = status
        @body = body
        super(message)
      end
    end
  end
end
