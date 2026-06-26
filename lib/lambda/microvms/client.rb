# frozen_string_literal: true

begin
  require 'aws-sdk-lambda'
rescue LoadError
  nil
end

module Lambda
  module MicroVMs
    # Ruby wrapper over Aws::Lambda::Client for Lambda MicroVM lifecycle operations.
    class Client
      # SDK methods this wrapper expects from Aws::Lambda::Client.
      REQUIRED_OPERATIONS = Adapters::MicroVMSdk::REQUIRED_OPERATIONS

      attr_reader :sdk, :adapter

      def initialize(region: nil, profile: nil, sdk: nil, adapter: nil, **)
        @sdk = sdk || build_sdk(region: region, profile: profile, **)
        @adapter = adapter || Adapters::MicroVMSdk.new(@sdk)
      end

      # Return wrapper operations missing from the given SDK client.
      #
      # @param sdk [Object, nil] SDK client to inspect
      # @return [Array<Symbol>] missing SDK operation names
      def self.unsupported_operations(sdk = nil)
        sdk ||= Aws::Lambda::Client.new(stub_responses: true) if defined?(Aws::Lambda::Client)
        return REQUIRED_OPERATIONS unless sdk

        Adapters::MicroVMSdk.new(sdk).unsupported_operations
      end

      # Check whether the given SDK client exposes all MicroVM operations.
      #
      # @param sdk [Object, nil] SDK client to inspect
      # @return [Boolean]
      def self.sdk_contract_supported?(sdk = nil)
        unsupported_operations(sdk).empty?
      end

      # Build an image resource wrapper without fetching it.
      #
      # @param arn [String] MicroVM image ARN
      # @return [Image] image resource wrapper
      def image(arn)
        Image.new(client: self, arn: arn)
      end

      # Build a MicroVM resource wrapper without fetching it.
      #
      # @param id_or_arn [String] MicroVM id or ARN
      # @return [MicroVM] MicroVM resource wrapper
      def microvm(id_or_arn)
        MicroVM.new(client: self, id: id_or_arn)
      end

      # Create a MicroVM image through the Lambda SDK.
      #
      # @param params [Hash] SDK request parameters
      # @return [Image] created image resource
      def create_image(**params)
        response = call_sdk(:create_microvm_image, **params)
        Image.from_response(client: self, response: response)
      end

      # Fetch a MicroVM image and wrap the SDK response.
      #
      # @param params [Hash] SDK request parameters
      # @return [Image] fetched image resource
      def get_image(**params)
        response = call_sdk(:get_microvm_image, **params)
        Image.from_response(client: self, response: response)
      end

      # Delete a MicroVM image.
      #
      # @param params [Hash] SDK request parameters
      # @return [Object] raw SDK response
      def delete_image(**params)
        call_sdk(:delete_microvm_image, **params)
      end

      # Run a MicroVM from an image.
      #
      # @param params [Hash] SDK request parameters
      # @return [MicroVM] started MicroVM resource
      def run(**params)
        response = call_sdk(:run_microvm, **params)
        MicroVM.from_response(client: self, response: response)
      end
      alias run_microvm run

      # Fetch a MicroVM and wrap the SDK response.
      #
      # @param params [Hash] SDK request parameters
      # @return [MicroVM] fetched MicroVM resource
      def get_microvm(**params)
        response = call_sdk(:get_microvm, **params)
        MicroVM.from_response(client: self, response: response)
      end

      # List MicroVMs using the underlying Lambda SDK client.
      #
      # @param params [Hash] SDK request parameters
      # @return [Object] raw SDK response
      def list_microvms(**params)
        call_sdk(:list_microvms, **params)
      end

      # Suspend a MicroVM.
      #
      # @param params [Hash] SDK request parameters
      # @return [Object] raw SDK response
      def suspend_microvm(**params)
        call_sdk(:suspend_microvm, **params)
      end

      # Resume a suspended MicroVM.
      #
      # @param params [Hash] SDK request parameters
      # @return [Object] raw SDK response
      def resume_microvm(**params)
        call_sdk(:resume_microvm, **params)
      end

      # Terminate a MicroVM.
      #
      # @param params [Hash] SDK request parameters
      # @return [Object] raw SDK response
      def terminate_microvm(**params)
        call_sdk(:terminate_microvm, **params)
      end

      # Create an auth token for direct MicroVM endpoint access.
      #
      # @param params [Hash] SDK request parameters
      # @return [Object] raw SDK response
      def create_auth_token(**params)
        call_sdk(:create_microvm_auth_token, **params)
      end
      alias create_microvm_auth_token create_auth_token

      # Dispatch a supported operation to the underlying SDK client.
      #
      # @param operation [Symbol] SDK method name
      # @param params [Hash] SDK request parameters
      # @return [Object] raw SDK response
      # @raise [UnsupportedOperationError] when the SDK does not expose the operation
      def call_sdk(operation, **params)
        adapter.call(operation, **params)
      end

      private

      def build_sdk(region:, profile:, **options)
        raise LoadError, 'install aws-sdk-lambda to use Lambda::MicroVMs::Client' unless defined?(Aws::Lambda::Client)

        args = options.dup
        args[:region] = region if region
        args[:profile] = profile if profile
        Aws::Lambda::Client.new(**args)
      end
    end
  end
end
