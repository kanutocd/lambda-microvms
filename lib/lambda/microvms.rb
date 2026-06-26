# frozen_string_literal: true

require_relative 'microvms/version'
require_relative 'microvms/error'
require_relative 'microvms/util'
require_relative 'microvms/waiter'
require_relative 'microvms/endpoint'
require_relative 'microvms/client'
require_relative 'microvms/image'
require_relative 'microvms/microvm'
require_relative 'microvms/session'
require_relative 'microvms/project'
require_relative 'microvms/scaffold'
require_relative 'microvms/packager'
require_relative 'microvms/deployer'
require_relative 'microvms/doctor'

module Lambda
  # Idiomatic Ruby lifecycle helpers for AWS Lambda MicroVMs.
  module MicroVMs
    module_function

    def session(...)
      Session.session(...)
    end
  end
end
