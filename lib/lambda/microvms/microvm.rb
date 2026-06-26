# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Represents one running, suspended, or terminated Lambda MicroVM session.
    class MicroVM
      attr_reader :client, :id, :data

      def self.from_response(client:, response:)
        id = Util.extract(response, :microvm_id, :microvm_arn, :id, :arn)
        new(client: client, id: id, data: response)
      end

      def initialize(client:, id:, data: nil)
        @client = client
        @id = id
        @data = data
      end

      def refresh
        fresh = client.get_microvm(microvm_id: id)
        @data = fresh.data
        self
      end

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

      def endpoint_url
        endpoint = Util.extract(@data, :endpoint, :endpoint_url, :url)
        return endpoint if endpoint.is_a?(String)

        Util.extract(endpoint, :url, :endpoint_url) if endpoint
      end

      def auth_token(ports: nil, ttl_seconds: nil, **params)
        request = params.merge(microvm_id: id)
        request[:ports] = ports if ports
        request[:ttl_seconds] = ttl_seconds if ttl_seconds
        response = client.create_auth_token(**request)
        Util.extract(response, :token, :auth_token, :microvm_auth_token)
      end

      def endpoint(token: nil, **token_params)
        Endpoint.new(url: endpoint_url, token: token || auth_token(**token_params))
      end

      def get(path, token: nil, **)
        endpoint(token: token).get(path, **)
      end

      def post(path, json: nil, body: nil, token: nil, **)
        endpoint(token: token).post(path, json: json, body: body, **)
      end

      def suspend(**params)
        client.suspend_microvm(**params, microvm_id: id)
        self
      end

      def resume(**params)
        response = client.resume_microvm(**params, microvm_id: id)
        @data = response if response
        self
      end

      def terminate(**params)
        client.terminate_microvm(**params, microvm_id: id)
        self
      end

      def wait_until_running(delay: Waiter::DEFAULT_DELAY, timeout: Waiter::DEFAULT_TIMEOUT)
        Waiter.new(delay: delay, timeout: timeout).wait(message: "MicroVM #{id} to be running") do
          refresh.running?
        end
        self
      end

      def wait_until_suspended(delay: Waiter::DEFAULT_DELAY, timeout: Waiter::DEFAULT_TIMEOUT)
        Waiter.new(delay: delay, timeout: timeout).wait(message: "MicroVM #{id} to be suspended") do
          refresh.suspended?
        end
        self
      end

      def wait_until_terminated(delay: Waiter::DEFAULT_DELAY, timeout: Waiter::DEFAULT_TIMEOUT)
        Waiter.new(delay: delay, timeout: timeout).wait(message: "MicroVM #{id} to be terminated") do
          refresh.terminated?
        end
        self
      end
    end
  end
end
