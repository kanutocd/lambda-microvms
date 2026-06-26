# frozen_string_literal: true

require 'test_helper'

class ImageTest < Minitest::Test
  def test_image_run_injects_image_arn
    sdk = FakeSdk.new
    client = Lambda::MicroVMs::Client.new(sdk: sdk)
    image = client.image('image-1')

    image.run(role_arn: 'role-1', payload: { tenant_id: 't1' })

    assert_equal [:run_microvm, { image_arn: 'image-1', role_arn: 'role-1', payload: { tenant_id: 't1' } }],
                 sdk.calls.last
  end

  def test_wait_until_ready_refreshes_until_ready
    sdk = FakeSdk.new
    sdk.image_states = %i[building ready]
    image = Lambda::MicroVMs::Image.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), arn: 'image-1')

    image.wait_until_ready(delay: 0.001, timeout: 0.1)

    assert_predicate image, :ready?
  end
end
