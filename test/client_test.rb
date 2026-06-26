# frozen_string_literal: true

require 'test_helper'

class ClientTest < Minitest::Test
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
end
