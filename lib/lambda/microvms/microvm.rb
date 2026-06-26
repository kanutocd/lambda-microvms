# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Represents one running, suspended, or terminated Lambda MicroVM session.
    class MicroVM
      attr_reader :client, :id, :data

      # Build a MicroVM resource from an SDK response.
      #
      # @param client [Client] lifecycle client
      # @param response [Object] SDK response
      # @return [MicroVM] MicroVM resource
      def self.from_response(client:, response:)
        id = Util.extract(response, :microvm_id, :microvm_arn, :id, :arn)
        new(client: client, id: id, data: response)
      end

      def initialize(client:, id:, data: nil)
        @client = client
        @id = id
        @data = data
      end

      # Refresh MicroVM data from the service.
      #
      # @return [self]
      def refresh
        fresh = client.get_microvm(microvm_id: id)
        @data = fresh.data
        self
      end

      # Current normalized MicroVM state.
      #
      # @return [Symbol]
      def state
        Util.normalize_state(Util.extract(@data, :state, :status, :microvm_state))
      end

      def running?
        state == :running
      end

      def suspended?
        state == :suspended
      end

      def terminated?
        state == :terminated
      end

      def pending?
        state == :pending
      end

      # Extract the direct endpoint URL from the current MicroVM data.
      #
      # @return [String, nil]
      def endpoint_url
        endpoint = Util.extract(@data, :endpoint, :endpoint_url, :url)
        return endpoint if endpoint.is_a?(String)

        Util.extract(endpoint, :url, :endpoint_url) if endpoint
      end

      # Request an auth token for direct endpoint access.
      #
      # @param ports [Array<Integer>, nil] optional allowed ports
      # @param ttl_seconds [Integer, nil] optional token lifetime
      # @param params [Hash] additional token request parameters
      # @return [String, nil] auth token value
      def auth_token(ports: nil, ttl_seconds: nil, **params)
        request = params.merge(microvm_id: id)
        request[:ports] = ports if ports
        request[:ttl_seconds] = ttl_seconds if ttl_seconds
        response = client.create_auth_token(**request)
        Util.extract(response, :token, :auth_token, :microvm_auth_token)
      end

      # Build an endpoint client for this MicroVM.
      #
      # @param token [String, nil] existing auth token
      # @param token_params [Hash] parameters used when requesting a token
      # @return [Endpoint]
      def endpoint(token: nil, **token_params)
        Endpoint.new(url: endpoint_url, token: token || auth_token(**token_params))
      end

      # Send a GET request to the MicroVM endpoint.
      #
      # @param path [String] endpoint path
      # @param token [String, nil] existing auth token
      # @return [Hash,String,nil] endpoint response
      def get(path, token: nil, **)
        endpoint(token: token).get(path, **)
      end

      # Send a POST request to the MicroVM endpoint.
      #
      # @param path [String] endpoint path
      # @param json [Hash,Array,nil] JSON body to encode
      # @param body [String,nil] raw request body
      # @param token [String, nil] existing auth token
      # @return [Hash,String,nil] endpoint response
      def post(path, json: nil, body: nil, token: nil, **)
        endpoint(token: token).post(path, json: json, body: body, **)
      end

      # Suspend this MicroVM.
      #
      # @param params [Hash] additional suspend parameters
      # @return [self]
      def suspend(**params)
        client.suspend_microvm(**params, microvm_id: id)
        self
      end

      # Resume this MicroVM and update local data when the service returns a response.
      #
      # @param params [Hash] additional resume parameters
      # @return [self]
      def resume(**params)
        response = client.resume_microvm(**params, microvm_id: id)
        @data = response if response
        self
      end

      # Terminate this MicroVM.
      #
      # @param params [Hash] additional terminate parameters
      # @return [self]
      def terminate(**params)
        client.terminate_microvm(**params, microvm_id: id)
        self
      end

      # Wait until this MicroVM is running.
      #
      # @param delay [Numeric] polling delay in seconds
      # @param timeout [Numeric] maximum wait in seconds
      # @return [self]
      def wait_until_running(delay: Waiter::DEFAULT_DELAY, timeout: Waiter::DEFAULT_TIMEOUT)
        Waiter.new(delay: delay, timeout: timeout).wait(message: "MicroVM #{id} to be running") do
          refresh.running?
        end
        self
      end

      # Wait until this MicroVM is suspended.
      #
      # @param delay [Numeric] polling delay in seconds
      # @param timeout [Numeric] maximum wait in seconds
      # @return [self]
      def wait_until_suspended(delay: Waiter::DEFAULT_DELAY, timeout: Waiter::DEFAULT_TIMEOUT)
        Waiter.new(delay: delay, timeout: timeout).wait(message: "MicroVM #{id} to be suspended") do
          refresh.suspended?
        end
        self
      end

      # Wait until this MicroVM is terminated.
      #
      # @param delay [Numeric] polling delay in seconds
      # @param timeout [Numeric] maximum wait in seconds
      # @return [self]
      def wait_until_terminated(delay: Waiter::DEFAULT_DELAY, timeout: Waiter::DEFAULT_TIMEOUT)
        Waiter.new(delay: delay, timeout: timeout).wait(message: "MicroVM #{id} to be terminated") do
          refresh.terminated?
        end
        self
      end
    end
  end
end
