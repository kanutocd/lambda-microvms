# frozen_string_literal: true

module Lambda
  module MicroVMs
    # Internal helpers shared by resource objects.
    module Util
      module_function

      # Extract the first non-nil value from an object method or hash-like key.
      #
      # @param value [Object] response object, hash, or SDK structure
      # @param keys [Array<Symbol,String>] candidate method or key names
      # @return [Object, nil] the first extracted non-nil value
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

      # Normalize a provider state value into a lowercase symbol.
      #
      # @param value [Object] state-like value
      # @return [Symbol] normalized state
      def normalize_state(value)
        value.to_s.downcase.to_sym
      end
    end
  end
end
