# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Convenience API for run/use/cleanup MicroVM sessions.
    module Session
      module_function

# Run a MicroVM, wait for it, yield it, and then clean it up.
      #
      # @param image_arn [String] MicroVM image ARN
      # @param role_arn [String] IAM role ARN for the MicroVM runtime
      # @param after [Symbol, nil] cleanup policy: :suspend, :terminate, :keep, or nil
      # @param client [Client] lifecycle client
      # @param run_options [Hash] additional run parameters
      # @yieldparam vm [MicroVM] running MicroVM
      # @return [Object] block result
      def session(image_arn:, role_arn:, after: :suspend, client: Client.new, **run_options)
        vm = client.image(image_arn).run(role_arn: role_arn, **run_options)
        vm.wait_until_running
        yield vm
      ensure
        cleanup(vm, after) if vm
      end

# Apply a session cleanup policy to a MicroVM.
      #
      # @param vm [MicroVM] MicroVM to clean up
      # @param after [Symbol, nil] cleanup policy
      # @return [Object, nil] cleanup result
      # @raise [ArgumentError] when the policy is unknown
      def cleanup(vm, after) # rubocop:disable Naming/MethodParameterName
        case after
        when :keep, nil
          nil
        when :suspend
          vm.suspend
        when :terminate
          vm.terminate
        else
          raise ArgumentError, "unknown cleanup policy: #{after.inspect}"
        end
      end
    end
  end
end
