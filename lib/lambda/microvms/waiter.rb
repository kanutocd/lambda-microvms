# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Polls a resource until a desired lifecycle state is reached.
    class Waiter
      DEFAULT_DELAY = 1.0
      DEFAULT_TIMEOUT = 60.0

      def initialize(delay: DEFAULT_DELAY, timeout: DEFAULT_TIMEOUT, sleeper: Kernel)
        @delay = delay
        @timeout = timeout
        @sleeper = sleeper
      end

      def wait(message: 'condition')
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout

        loop do
          value = yield
          return value if value

          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break if now >= deadline

          @sleeper.sleep([@delay, deadline - now].min)
        end

        raise WaitTimeoutError, "timed out waiting for #{message}"
      end
    end
  end
end
