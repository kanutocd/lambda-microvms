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
      attr_reader :sdk

      def initialize(region: nil, profile: nil, sdk: nil, **)
        @sdk = sdk || build_sdk(region:, profile:, **)
      end

      def image(arn)
        Image.new(client: self, arn: arn)
      end

      def microvm(id_or_arn)
        MicroVM.new(client: self, id: id_or_arn)
      end

      def create_image(**params)
        response = call_sdk(:create_microvm_image, **params)
        Image.from_response(client: self, response: response)
      end

      def get_image(**params)
        response = call_sdk(:get_microvm_image, **params)
        Image.from_response(client: self, response: response)
      end

      def delete_image(**params)
        call_sdk(:delete_microvm_image, **params)
      end

      def run(**params)
        response = call_sdk(:run_microvm, **params)
        MicroVM.from_response(client: self, response: response)
      end
      alias run_microvm run

      def get_microvm(**params)
        response = call_sdk(:get_microvm, **params)
        MicroVM.from_response(client: self, response: response)
      end

      def list_microvms(**params)
        call_sdk(:list_microvms, **params)
      end

      def suspend_microvm(**params)
        call_sdk(:suspend_microvm, **params)
      end

      def resume_microvm(**params)
        call_sdk(:resume_microvm, **params)
      end

      def terminate_microvm(**params)
        call_sdk(:terminate_microvm, **params)
      end

      def create_auth_token(**params)
        call_sdk(:create_microvm_auth_token, **params)
      end
      alias create_microvm_auth_token create_auth_token

      def call_sdk(operation, **params)
        unless @sdk.respond_to?(operation)
          raise UnsupportedOperationError, "Aws::Lambda::Client does not expose ##{operation}; upgrade aws-sdk-lambda"
        end

        @sdk.public_send(operation, **params)
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
