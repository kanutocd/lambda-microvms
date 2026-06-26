# frozen_string_literal: true

require 'test_helper'

class SessionTest < Minitest::Test
  def test_session_suspends_after_block
    sdk = FakeSdk.new
    client = Lambda::MicroVMs::Client.new(sdk: sdk)
    yielded = nil

    Lambda::MicroVMs.session(image_arn: 'image-1', role_arn: 'role-1', client: client, after: :suspend) do |vm|
      yielded = vm
    end

    assert_instance_of Lambda::MicroVMs::MicroVM, yielded
    assert_includes sdk.calls, [:suspend_microvm, { microvm_id: 'vm-1' }]
  end

  def test_session_terminates_after_block
    sdk = FakeSdk.new
    client = Lambda::MicroVMs::Client.new(sdk: sdk)

    Lambda::MicroVMs.session(image_arn: 'image-1', role_arn: 'role-1', client: client, after: :terminate) { |_vm| } # rubocop:disable Lint/EmptyBlock

    assert_includes sdk.calls, [:terminate_microvm, { microvm_id: 'vm-1' }]
  end
end
