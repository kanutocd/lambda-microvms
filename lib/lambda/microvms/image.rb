# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Represents a Lambda MicroVM image/snapshot artifact.
    class Image
      attr_reader :client, :arn, :data

      # Build an image resource from an SDK response.
      #
      # @param client [Client] lifecycle client
      # @param response [Object] SDK response
      # @return [Image] image resource
      def self.from_response(client:, response:)
        arn = Util.extract(response, :image_arn, :microvm_image_arn, :arn)
        new(client: client, arn: arn, data: response)
      end

      def initialize(client:, arn:, data: nil)
        @client = client
        @arn = arn
        @data = data
      end

      # Refresh image data from the service.
      #
      # @return [self]
      def refresh
        fresh = client.get_image(image_arn: arn)
        @data = fresh.data
        self
      end

      # Current normalized image state.
      #
      # @return [Symbol]
      def state
        Util.normalize_state(Util.extract(@data, :state, :status, :image_state))
      end

      def ready?
        %i[ready available active].include?(state)
      end

      # Wait until the image reaches a ready-like state.
      #
      # @param delay [Numeric] polling delay in seconds
      # @param timeout [Numeric] maximum wait in seconds
      # @return [self]
      def wait_until_ready(delay: Waiter::DEFAULT_DELAY, timeout: Waiter::DEFAULT_TIMEOUT)
        Waiter.new(delay: delay, timeout: timeout).wait(message: "image #{arn} to be ready") do
          refresh.ready?
        end
        self
      end

      # Run a MicroVM from this image.
      #
      # @param role_arn [String] IAM role ARN used by the MicroVM runtime
      # @param payload [Object,nil] optional runtime payload
      # @param params [Hash] additional run parameters
      # @return [MicroVM]
      def run(role_arn:, payload: nil, **params)
        request = params.merge(image_arn: arn, role_arn: role_arn)
        request[:payload] = payload if payload
        client.run(**request)
      end
    end
  end
end
