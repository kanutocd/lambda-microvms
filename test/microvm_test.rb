# frozen_string_literal: true

require 'test_helper'

class MicroVMTest < Minitest::Test
  FakeEndpoint = Struct.new(:calls, keyword_init: true) do
    def get(path, **params)
      calls << [:get, path, params]
      :got
    end

    def post(path, **params)
      calls << [:post, path, params]
      :posted
    end
  end

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

  def test_auth_token_omits_optional_params
    sdk = FakeSdk.new
    vm = Lambda::MicroVMs::MicroVM.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), id: 'vm-1')

    assert_equal 'token-1', vm.auth_token
    assert_equal [:create_microvm_auth_token, { microvm_id: 'vm-1' }], sdk.calls.last
  end

  def test_wait_until_running_refreshes_until_running
    sdk = FakeSdk.new
    sdk.microvm_states = %i[pending running]
    vm = Lambda::MicroVMs::MicroVM.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), id: 'vm-1')

    vm.wait_until_running(delay: 0.001, timeout: 0.1)

    assert_predicate vm, :running?
  end

  def test_state_predicates_for_suspended_terminated_and_pending
    assert_predicate microvm_with(state: 'SUSPENDED'), :suspended?
    assert_predicate microvm_with(state: 'TERMINATED'), :terminated?
    assert_predicate microvm_with(state: 'PENDING'), :pending?
  end

  def test_endpoint_url_extracts_string_and_nested_shapes
    assert_equal 'https://one.test', microvm_with(endpoint_url: 'https://one.test').endpoint_url
    assert_equal 'https://two.test', microvm_with(endpoint: { url: 'https://two.test' }).endpoint_url
    assert_nil microvm_with(state: 'PENDING').endpoint_url
  end

  def test_endpoint_builds_token
    sdk = FakeSdk.new
    vm = Lambda::MicroVMs::MicroVM.new(
      client: Lambda::MicroVMs::Client.new(sdk: sdk),
      id: 'vm-1',
      data: { endpoint_url: 'https://example.test' }
    )

    assert_instance_of Lambda::MicroVMs::Endpoint, vm.endpoint(ports: [3000])
    assert_equal [:create_microvm_auth_token, { microvm_id: 'vm-1', ports: [3000] }], sdk.calls.last
  end

  def test_http_helpers_delegate_to_endpoint
    fake_endpoint = FakeEndpoint.new(calls: [])
    vm = microvm_with(endpoint_url: 'https://example.test')
    vm.define_singleton_method(:endpoint) { |**_params| fake_endpoint }

    assert_equal :got, vm.get('/health', token: 'token')
    assert_equal :posted, vm.post('/jobs', json: { ok: true }, token: 'token')
    assert_equal [[:get, '/health', {}], [:post, '/jobs', { json: { ok: true }, body: nil }]], fake_endpoint.calls
  end

  def test_endpoint_raises_when_url_is_unavailable
    error = assert_raises(Lambda::MicroVMs::EndpointError) { microvm_with.endpoint(token: 'token') }

    assert_equal 'MicroVM endpoint URL is unavailable', error.message
    assert_equal 0, error.status
    assert_nil error.body
  end

  def test_waits_for_suspended_and_terminated_states
    sdk = FakeSdk.new
    sdk.microvm_states = %i[running suspended running terminated]
    vm = Lambda::MicroVMs::MicroVM.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), id: 'vm-1')

    assert_same vm, vm.wait_until_suspended(delay: 0.001, timeout: 0.1)
    assert_same vm, vm.wait_until_terminated(delay: 0.001, timeout: 0.1)
  end

  def test_resume_preserves_data_when_sdk_returns_nil
    client = Object.new
    def client.resume_microvm(**_params) = nil

    vm = Lambda::MicroVMs::MicroVM.new(client: client, id: 'vm-1', data: { state: 'suspended' })

    assert_same vm, vm.resume
    assert_predicate vm, :suspended?
  end

  private

  def microvm_with(data = {})
    Lambda::MicroVMs::MicroVM.new(client: Object.new, id: 'vm-1', data: data)
  end
end
