# frozen_string_literal: true

require 'json'

module Lambda
  module MicroVMs
    # Thin wrapper over stable Aws::Lambda::Client function APIs.
    class FunctionClient
      attr_reader :sdk

      def initialize(region: nil, profile: nil, sdk: nil, **)
        @sdk = sdk || build_sdk(region: region, profile: profile, **)
      end

      # Create a Lambda function from a zip file using supported AWS APIs.
      #
      # @param name [String] function name
      # @param role_arn [String] IAM role ARN
      # @param handler [String] handler name
      # @param runtime [String] Lambda runtime identifier
      # @param zip_file [String] path to deployment zip
      # @param params [Hash] additional create_function parameters
      # @return [Object] raw SDK response
      def create_function(name:, role_arn:, handler:, runtime:, zip_file:, **params) # rubocop:disable Metrics/ParameterLists
        sdk.create_function(
          **params,
          function_name: name,
          role: role_arn,
          handler: handler,
          runtime: runtime,
          code: { zip_file: File.binread(zip_file) }
        )
      end

      # Update Lambda function code from a zip file.
      #
      # @param function_name [String] function name or ARN
      # @param zip_file [String] path to deployment zip
      # @param params [Hash] additional update_function_code parameters
      # @return [Object] raw SDK response
      def update_function_code(function_name:, zip_file:, **params)
        sdk.update_function_code(**params, function_name: function_name, zip_file: File.binread(zip_file))
      end

      # Invoke a Lambda function and parse JSON payloads when possible.
      #
      # @param function_name [String] function name or ARN
      # @param payload [Object] request payload
      # @param params [Hash] additional invoke parameters
      # @return [Object] parsed response payload or raw response body
      def invoke(function_name:, payload: nil, **params)
        response = sdk.invoke(**params, function_name: function_name, payload: encode_payload(payload))
        parse_payload(response.payload)
      end

      private

      def build_sdk(region:, profile:, **options)
        unless defined?(Aws::Lambda::Client)
          raise LoadError, 'install aws-sdk-lambda to use Lambda::MicroVMs::FunctionClient'
        end

        args = options.dup
        args[:region] = region if region
        args[:profile] = profile if profile
        Aws::Lambda::Client.new(**args)
      end

      def encode_payload(payload)
        case payload
        when nil
          nil
        when String
          payload
        else
          JSON.generate(payload)
        end
      end

      def parse_payload(payload)
        body = payload.respond_to?(:read) ? payload.read : payload.to_s
        return nil if body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        body
      end
    end
  end
end
