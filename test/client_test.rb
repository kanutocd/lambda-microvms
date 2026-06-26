# frozen_string_literal: true

require 'test_helper'

class ClientTest < Minitest::Test
  FakeAwsClient = Class.new do
    attr_reader :args

    def initialize(**args)
      @args = args
    end
  end

  def test_wraps_create_image_response
    client = Lambda::MicroVMs::Client.new(sdk: FakeSdk.new)

    image = client.create_image(name: 'ruby')

    assert_instance_of Lambda::MicroVMs::Image, image
    assert_equal 'image-1', image.arn
    assert_predicate image, :ready?
  end

  def test_run_returns_microvm_resource
    sdk = FakeSdk.new
    client = Lambda::MicroVMs::Client.new(sdk: sdk)

    vm = client.run(image_arn: 'image-1', role_arn: 'role-1')

    assert_instance_of Lambda::MicroVMs::MicroVM, vm
    assert_equal 'vm-1', vm.id
    assert_equal :pending, vm.state
    assert_equal [:run_microvm, { image_arn: 'image-1', role_arn: 'role-1' }], sdk.calls.last
  end

  def test_raises_when_operation_missing
    client = Lambda::MicroVMs::Client.new(sdk: Object.new)

    error = assert_raises(Lambda::MicroVMs::UnsupportedOperationError) do
      client.run(image_arn: 'image-1', role_arn: 'role-1')
    end

    assert_match(/run_microvm/, error.message)
  end

  def test_delegates_through_microvm_adapter
    sdk = FakeSdk.new
    adapter = Lambda::MicroVMs::Adapters::MicroVMSdk.new(sdk)
    client = Lambda::MicroVMs::Client.new(sdk: sdk, adapter: adapter)

    client.run(image_arn: 'image-1', role_arn: 'role-1')

    assert_equal [], adapter.unsupported_operations
    assert_predicate adapter, :supported?
    assert_equal [:run_microvm, { image_arn: 'image-1', role_arn: 'role-1' }], sdk.calls.last
  end

  def test_resource_helpers_and_passthrough_operations
    sdk = FakeSdk.new
    client = Lambda::MicroVMs::Client.new(sdk: sdk)

    assert_instance_of Lambda::MicroVMs::MicroVM, client.microvm('vm-1')
    assert_equal({ deleted: true }, client.delete_image(image_arn: 'image-1'))
    assert_equal({ microvms: [] }, client.list_microvms(max_results: 1))
  end

  def test_builds_default_aws_sdk_with_region_profile_and_options
    with_aws_constant(:Lambda, FakeAwsClient) do
      client = Lambda::MicroVMs::Client.new(region: 'us-east-1', profile: 'dev', retry_limit: 2)

      assert_equal({ retry_limit: 2, region: 'us-east-1', profile: 'dev' }, client.sdk.args)
    end
  end

  def test_builds_default_aws_sdk_without_optional_region_or_profile
    with_aws_constant(:Lambda, FakeAwsClient) do
      client = Lambda::MicroVMs::Client.new(retry_limit: 1)

      assert_equal({ retry_limit: 1 }, client.sdk.args)
    end
  end

  def test_raises_when_aws_lambda_sdk_is_missing
    without_aws_constant(:Lambda) do
      assert_raises(LoadError) { Lambda::MicroVMs::Client.new }
    end
  end

  def test_sdk_contract_reports_missing_operations
    sdk = Object.new

    assert_equal Lambda::MicroVMs::Client::REQUIRED_OPERATIONS, Lambda::MicroVMs::Client.unsupported_operations(sdk)
    refute Lambda::MicroVMs::Client.sdk_contract_supported?(sdk)
  end

  def test_sdk_contract_reports_missing_operations_when_aws_client_is_unavailable
    without_aws_constant(:Lambda) do
      assert_equal Lambda::MicroVMs::Client::REQUIRED_OPERATIONS, Lambda::MicroVMs::Client.unsupported_operations
    end
  end

  def test_sdk_contract_inspects_default_aws_client
    refute_empty Lambda::MicroVMs::Client.unsupported_operations
  end

  def test_sdk_contract_accepts_client_with_required_operations
    sdk = Object.new
    Lambda::MicroVMs::Client::REQUIRED_OPERATIONS.each do |operation|
      sdk.define_singleton_method(operation) { nil }
    end

    assert_empty Lambda::MicroVMs::Client.unsupported_operations(sdk)
    assert Lambda::MicroVMs::Client.sdk_contract_supported?(sdk)
  end
end
