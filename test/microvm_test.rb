# frozen_string_literal: true

require 'test_helper'

class MicroVMTest < Minitest::Test
  def test_lifecycle_methods_call_sdk_with_microvm_id
    sdk = FakeSdk.new
    vm = Lambda::MicroVMs::MicroVM.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), id: 'vm-1')

    vm.suspend
    vm.resume
    vm.terminate(reason: 'done')

    assert_includes sdk.calls, [:suspend_microvm, { microvm_id: 'vm-1' }]
    assert_includes sdk.calls, [:resume_microvm, { microvm_id: 'vm-1' }]
    assert_includes sdk.calls, [:terminate_microvm, { reason: 'done', microvm_id: 'vm-1' }]
  end

  def test_auth_token_extracts_token
    sdk = FakeSdk.new
    vm = Lambda::MicroVMs::MicroVM.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), id: 'vm-1')

    assert_equal 'token-1', vm.auth_token(ports: [8080], ttl_seconds: 60)
    assert_equal [:create_microvm_auth_token, { microvm_id: 'vm-1', ports: [8080], ttl_seconds: 60 }], sdk.calls.last
  end

  def test_wait_until_running_refreshes_until_running
    sdk = FakeSdk.new
    sdk.microvm_states = %i[pending running]
    vm = Lambda::MicroVMs::MicroVM.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), id: 'vm-1')

    vm.wait_until_running(delay: 0.001, timeout: 0.1)

    assert_predicate vm, :running?
  end
end
