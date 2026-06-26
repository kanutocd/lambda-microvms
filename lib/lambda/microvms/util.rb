# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Internal helpers shared by resource objects.
    module Util
      module_function

      def extract(value, *keys)
        keys.each do |key|
          if value.respond_to?(key)
            result = value.public_send(key)
            return result unless result.nil?
          end

          next unless value.respond_to?(:[])

          begin
            result = value[key]
            return result unless result.nil?
          rescue KeyError, TypeError
            nil
          end
        end

        nil
      end

      def normalize_state(value)
        value.to_s.downcase.to_sym
      end
    end
  end
end
