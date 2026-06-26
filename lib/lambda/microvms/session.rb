# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Convenience API for run/use/cleanup MicroVM sessions.
    module Session
      module_function

      def session(image_arn:, role_arn:, after: :suspend, client: Client.new, **run_options)
        vm = client.image(image_arn).run(role_arn: role_arn, **run_options)
        vm.wait_until_running
        yield vm
      ensure
        cleanup(vm, after) if vm
      end

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
