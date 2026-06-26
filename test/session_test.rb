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

  def test_keep_and_nil_cleanup_policies_do_nothing
    vm = Lambda::MicroVMs::MicroVM.new(client: Object.new, id: 'vm-1')

    assert_nil Lambda::MicroVMs::Session.cleanup(vm, :keep)
    assert_nil Lambda::MicroVMs::Session.cleanup(vm, nil)
  end

  def test_unknown_cleanup_policy_raises
    vm = Lambda::MicroVMs::MicroVM.new(client: Object.new, id: 'vm-1')

    assert_raises(ArgumentError) { Lambda::MicroVMs::Session.cleanup(vm, :explode) }
  end

  def test_session_cleans_up_when_block_raises
    sdk = FakeSdk.new
    client = Lambda::MicroVMs::Client.new(sdk: sdk)

    assert_raises(RuntimeError) do
      Lambda::MicroVMs.session(image_arn: 'image-1', role_arn: 'role-1', client: client, after: :terminate) do
        raise 'boom'
      end
    end

    assert_includes sdk.calls, [:terminate_microvm, { microvm_id: 'vm-1' }]
  end

  def test_session_does_not_cleanup_when_run_fails_before_vm_exists
    client = Object.new
    def client.image(_arn) = raise 'run failed'

    assert_raises(RuntimeError) do
      Lambda::MicroVMs.session(image_arn: 'image-1', role_arn: 'role-1', client: client) { nil }
    end
  end
end
