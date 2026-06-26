# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Represents a Lambda MicroVM image/snapshot artifact.
    class Image
      attr_reader :client, :arn, :data

      def self.from_response(client:, response:)
        arn = Util.extract(response, :image_arn, :microvm_image_arn, :arn)
        new(client: client, arn: arn, data: response)
      end

      def initialize(client:, arn:, data: nil)
        @client = client
        @arn = arn
        @data = data
      end

      def refresh
        fresh = client.get_image(image_arn: arn)
        @data = fresh.data
        self
      end

      def state
        Util.normalize_state(Util.extract(@data, :state, :status, :image_state))
      end

      def ready?
        %i[ready available active].include?(state)
      end

      def wait_until_ready(delay: Waiter::DEFAULT_DELAY, timeout: Waiter::DEFAULT_TIMEOUT)
        Waiter.new(delay: delay, timeout: timeout).wait(message: "image #{arn} to be ready") do
          refresh.ready?
        end
        self
      end

      def run(role_arn:, payload: nil, **params)
        request = params.merge(image_arn: arn, role_arn: role_arn)
        request[:payload] = payload if payload
        client.run(**request)
      end
    end
  end
end
