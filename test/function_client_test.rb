# frozen_string_literal: true

require 'stringio'
require 'test_helper'
require 'tmpdir'

class FunctionClientTest < Minitest::Test
  FakeFunctionSdk = Struct.new(:calls, :response, keyword_init: true) do
    def create_function(**params)
      calls << [:create_function, params]
      response || { function_name: params.fetch(:function_name) }
    end

    def update_function_code(**params)
      calls << [:update_function_code, params]
      response || { function_name: params.fetch(:function_name) }
    end

    def invoke(**params)
      calls << [:invoke, params]
      response || Struct.new(:payload).new(StringIO.new('{"ok":true}'))
    end
  end

  FakeAwsClient = Class.new do
    attr_reader :args

    def initialize(**args)
      @args = args
    end
  end

  def test_create_function_uses_supported_lambda_api
    sdk = FakeFunctionSdk.new(calls: [])
    zip = write_zip

    Lambda::MicroVMs::FunctionClient.new(sdk: sdk).create_function(
      name: 'worker',
      role_arn: 'arn:role',
      handler: 'app.Handler.process',
      runtime: 'ruby3.4',
      zip_file: zip,
      timeout: 30
    )

    assert_equal :create_function, sdk.calls.first.first
    assert_equal 'worker', sdk.calls.first.last.fetch(:function_name)
    assert_equal 'zip-bytes', sdk.calls.first.last.fetch(:code).fetch(:zip_file)
  end

  def test_update_function_code_reads_zip
    sdk = FakeFunctionSdk.new(calls: [])

    Lambda::MicroVMs::FunctionClient.new(sdk: sdk).update_function_code(function_name: 'worker', zip_file: write_zip)

    assert_equal [:update_function_code, { function_name: 'worker', zip_file: 'zip-bytes' }], sdk.calls.first
  end

  def test_invoke_generates_and_parses_json_payloads
    sdk = FakeFunctionSdk.new(calls: [])

    result = Lambda::MicroVMs::FunctionClient.new(sdk: sdk).invoke(function_name: 'worker', payload: { hello: 'world' })

    assert_equal({ 'ok' => true }, result)
    assert_equal '{"hello":"world"}', sdk.calls.first.last.fetch(:payload)
  end

  def test_invoke_returns_plain_payload_when_not_json
    sdk = FakeFunctionSdk.new(calls: [], response: Struct.new(:payload).new(StringIO.new('plain')))

    assert_equal 'plain', Lambda::MicroVMs::FunctionClient.new(sdk: sdk).invoke(function_name: 'worker')
  end

  def test_invoke_preserves_string_payload
    sdk = FakeFunctionSdk.new(calls: [])

    Lambda::MicroVMs::FunctionClient.new(sdk: sdk).invoke(function_name: 'worker', payload: '{"raw":true}')

    assert_equal '{"raw":true}', sdk.calls.first.last.fetch(:payload)
  end

  def test_invoke_allows_nil_payload_and_empty_response
    sdk = FakeFunctionSdk.new(calls: [], response: Struct.new(:payload).new(StringIO.new('')))

    assert_nil Lambda::MicroVMs::FunctionClient.new(sdk: sdk).invoke(function_name: 'worker')
    assert_nil sdk.calls.first.last.fetch(:payload)
  end

  def test_invoke_parses_non_io_payloads
    sdk = FakeFunctionSdk.new(calls: [], response: Struct.new(:payload).new('{"ok":true}'))

    assert_equal({ 'ok' => true }, Lambda::MicroVMs::FunctionClient.new(sdk: sdk).invoke(function_name: 'worker'))
  end

  def test_builds_default_aws_sdk_with_region_profile_and_options
    with_aws_constant(:Lambda, FakeAwsClient) do
      client = Lambda::MicroVMs::FunctionClient.new(region: 'us-east-1', profile: 'dev', retry_limit: 2)

      assert_equal({ retry_limit: 2, region: 'us-east-1', profile: 'dev' }, client.sdk.args)
    end
  end

  def test_builds_default_aws_sdk_without_optional_region_or_profile
    with_aws_constant(:Lambda, FakeAwsClient) do
      client = Lambda::MicroVMs::FunctionClient.new(retry_limit: 1)

      assert_equal({ retry_limit: 1 }, client.sdk.args)
    end
  end

  def test_raises_when_aws_lambda_sdk_is_missing
    without_aws_constant(:Lambda) do
      assert_raises(LoadError) { Lambda::MicroVMs::FunctionClient.new }
    end
  end

  private

  def write_zip
    dir = Dir.mktmpdir
    path = File.join(dir, 'function.zip')
    File.binwrite(path, 'zip-bytes')
    path
  end
end
