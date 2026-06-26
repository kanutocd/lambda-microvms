# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class CoverageRegressionTest < Minitest::Test
  GetterValue = Struct.new(:answer, keyword_init: true)
  NilGetterValue = Struct.new(:answer, keyword_init: true)

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

  FakeImage = Struct.new(:runs, keyword_init: true) do
    def run(**params)
      runs << params
      Lambda::MicroVMs::MicroVM.new(client: Object.new, id: 'vm-run')
    end
  end

  FakeRunClient = Struct.new(:image_resource, keyword_init: true) do
    def image(_arn)
      image_resource
    end
  end

  def test_util_extracts_from_reader_before_index_lookup
    assert_equal 'reader', Lambda::MicroVMs::Util.extract(GetterValue.new(answer: 'reader'), :answer)
  end

  def test_util_extracts_from_index_lookup_when_reader_returns_nil
    value = NilGetterValue.new(answer: nil)

    def value.[](key)
      key == :answer ? 'indexed' : nil
    end

    assert_equal 'indexed', Lambda::MicroVMs::Util.extract(value, :answer)
  end

  def test_util_extract_ignores_index_lookup_errors_and_returns_nil
    value = Object.new

    def value.[](_key)
      raise KeyError, 'missing'
    end

    assert_nil Lambda::MicroVMs::Util.extract(value, :missing)
  end

  def test_waiter_times_out_with_message
    waiter = Lambda::MicroVMs::Waiter.new(delay: 0.001, timeout: 0.001)

    error = assert_raises(Lambda::MicroVMs::WaitTimeoutError) do
      waiter.wait(message: 'thing') { false }
    end

    assert_equal 'timed out waiting for thing', error.message
  end

  def test_endpoint_get_root_returns_plain_body_without_authorization
    http = FakeHttp.new(Response.new(code: '204', body: '', headers: {}))
    endpoint = Lambda::MicroVMs::Endpoint.new(url: 'https://example.test/base', token: nil, http: http)

    assert_equal '', endpoint.get('/')
    assert_nil http.last_request['Authorization']
    assert_equal '/base', http.last_request.uri.path
  end

  def test_endpoint_post_raw_body_and_custom_header
    http = FakeHttp.new(Response.new(code: '202', body: 'accepted', headers: { 'Content-Type' => 'text/plain' }))
    endpoint = Lambda::MicroVMs::Endpoint.new(url: 'https://example.test/api/', token: 'token', http: http)

    assert_equal 'accepted', endpoint.post('jobs', body: 'raw', headers: { 'X-Test' => '1' })
    assert_equal 'raw', http.last_request.body
    assert_equal '/api/jobs', http.last_request.uri.path
    assert_equal '1', http.last_request['X-Test']
  end

  def test_client_resource_helpers_and_passthrough_operations
    sdk = FakeSdk.new
    client = Lambda::MicroVMs::Client.new(sdk: sdk)

    assert_instance_of Lambda::MicroVMs::MicroVM, client.microvm('vm-1')
    assert_equal({ deleted: true }, client.delete_image(image_arn: 'image-1'))
    assert_equal({ microvms: [] }, client.list_microvms(max_results: 1))
  end

  def test_client_builds_default_aws_sdk_with_region_profile_and_options
    client_class = Class.new do
      attr_reader :args

      def initialize(**args)
        @args = args
      end
    end
    with_aws_constant(:Lambda, client_class) do
      client = Lambda::MicroVMs::Client.new(region: 'us-east-1', profile: 'dev', retry_limit: 2)

      assert_equal({ retry_limit: 2, region: 'us-east-1', profile: 'dev' }, client.sdk.args)
    end
  end

  def test_client_builds_default_aws_sdk_without_optional_region_or_profile
    client_class = Class.new do
      attr_reader :args

      def initialize(**args)
        @args = args
      end
    end
    with_aws_constant(:Lambda, client_class) do
      client = Lambda::MicroVMs::Client.new(retry_limit: 1)

      assert_equal({ retry_limit: 1 }, client.sdk.args)
    end
  end

  def test_client_raises_when_aws_lambda_sdk_is_missing
    without_aws_constant(:Lambda) do
      assert_raises(LoadError) { Lambda::MicroVMs::Client.new }
    end
  end

  def test_microvm_state_predicates_and_endpoint_url_shapes
    string_endpoint = Lambda::MicroVMs::MicroVM.new(
      client: Object.new, id: 'vm-1', data: { state: 'SUSPENDED', endpoint_url: 'https://one.test' }
    )
    nested_endpoint = Lambda::MicroVMs::MicroVM.new(
      client: Object.new, id: 'vm-2', data: { state: 'TERMINATED', endpoint: { url: 'https://two.test' } }
    )
    pending = Lambda::MicroVMs::MicroVM.new(client: Object.new, id: 'vm-3', data: { state: 'PENDING' })

    assert_predicate string_endpoint, :suspended?
    assert_equal 'https://one.test', string_endpoint.endpoint_url
    assert_predicate nested_endpoint, :terminated?
    assert_equal 'https://two.test', nested_endpoint.endpoint_url
    assert_predicate pending, :pending?
    assert_nil pending.endpoint_url
  end

  def test_microvm_endpoint_builds_token_and_http_helpers_delegate
    sdk = FakeSdk.new
    vm = Lambda::MicroVMs::MicroVM.new(
      client: Lambda::MicroVMs::Client.new(sdk: sdk),
      id: 'vm-1',
      data: { endpoint_url: 'https://example.test' }
    )

    endpoint = vm.endpoint(ports: [3000])

    assert_instance_of Lambda::MicroVMs::Endpoint, endpoint
    assert_equal [:create_microvm_auth_token, { microvm_id: 'vm-1', ports: [3000] }], sdk.calls.last

    fake_endpoint = FakeEndpoint.new(calls: [])
    vm.define_singleton_method(:endpoint) { |token: nil, **_params| fake_endpoint }

    assert_equal :got, vm.get('/health', token: 'token')
    assert_equal :posted, vm.post('/jobs', json: { ok: true }, token: 'token')
    assert_equal [[:get, '/health', {}], [:post, '/jobs', { json: { ok: true }, body: nil }]], fake_endpoint.calls
  end

  def test_microvm_waits_for_suspended_and_terminated_states
    sdk = FakeSdk.new
    sdk.microvm_states = %i[running suspended running terminated]
    vm = Lambda::MicroVMs::MicroVM.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), id: 'vm-1')

    assert_same vm, vm.wait_until_suspended(delay: 0.001, timeout: 0.1)
    assert_same vm, vm.wait_until_terminated(delay: 0.001, timeout: 0.1)
  end

  def test_session_keep_policy_and_unknown_policy
    vm = Lambda::MicroVMs::MicroVM.new(client: Object.new, id: 'vm-1')

    assert_nil Lambda::MicroVMs::Session.cleanup(vm, :keep)
    assert_nil Lambda::MicroVMs::Session.cleanup(vm, nil)
    assert_raises(ArgumentError) { Lambda::MicroVMs::Session.cleanup(vm, :explode) }
  end

  def test_session_cleans_up_when_block_raises
    sdk = FakeSdk.new
    client = Lambda::MicroVMs::Client.new(sdk: sdk)

    assert_raises(RuntimeError) do
      Lambda::MicroVMs.session(image_arn: 'image-1', role_arn: 'role-1', client: client, after: :terminate) do |_vm|
        raise 'boom'
      end
    end

    assert_includes sdk.calls, [:terminate_microvm, { microvm_id: 'vm-1' }]
  end

  def test_project_payload_run_params_require_and_arrays
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), <<~YAML)
        name: demo
        role_arn: arn:role
        runtime:
          payload:
            tenant: t1
          run:
            environment:
              - name: A
                value: B
      YAML
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      assert_equal({ 'tenant' => 't1' }, project.payload)
      assert_equal(
        { environment: [{ 'name' => 'A', 'value' => 'B' }], role_arn: 'arn:role', payload: { 'tenant' => 't1' } },
        project.run_params
      )
      assert_equal 'x', project.require!('x', 'x')
      assert_raises(Lambda::MicroVMs::ConfigurationError) { project.require!('missing', '') }
    end
  end

  def test_project_run_params_preserve_explicit_role_and_empty_payload
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), <<~YAML)
        name: demo
        role_arn: arn:role
        runtime:
          payload:
          run:
            role_arn: explicit-role
            payload: {}
      YAML
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      assert_equal({}, project.payload)
      assert_equal({ role_arn: 'explicit-role', payload: {} }, project.run_params)
    end
  end

  def test_deployer_run_uses_configured_image_and_role
    image = FakeImage.new(runs: [])
    client = FakeRunClient.new(image_resource: image)

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), <<~YAML)
        name: demo
        role_arn: arn:role
        image:
          arn: arn:image
        runtime:
          run:
            memory_size: 512
      YAML
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      vm = Lambda::MicroVMs::Deployer.new(project: project, client: client, s3: Object.new).run

      assert_equal 'vm-run', vm.id
      assert_equal({ memory_size: 512, role_arn: 'arn:role' }, image.runs.first)
    end
  end

  def test_deployer_builds_default_s3_client_with_and_without_options
    s3_class = Class.new do
      attr_reader :args

      def initialize(**args)
        @args = args
      end
    end

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), "name: demo\nregion: us-east-1\nprofile: dev\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      with_aws_constant(:S3, s3_class) do
        s3 = Lambda::MicroVMs::Deployer.new(project: project, client: Object.new).s3

        assert_equal({ region: 'us-east-1', profile: 'dev' }, s3.args)
      end

      File.write(File.join(dir, 'microvm.yml'), "name: demo\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
      with_aws_constant(:S3, s3_class) do
        s3 = Lambda::MicroVMs::Deployer.new(project: project, client: Object.new).s3

        assert_equal({}, s3.args)
      end
    end
  end

  def test_deployer_raises_when_s3_sdk_is_missing
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), "name: demo\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      without_aws_constant(:S3) do
        assert_raises(LoadError) { Lambda::MicroVMs::Deployer.new(project: project, client: Object.new) }
      end
    end
  end

  def test_packager_returns_explicit_output_and_raises_on_zip_failure
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), "name: demo\n")
      File.write(File.join(dir, 'app.rb'), "puts :ok\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
      absolute_output = File.join(Dir.mktmpdir, 'artifact.zip')

      assert_equal absolute_output, Lambda::MicroVMs::Packager.new(project).package(output: absolute_output)

      FileUtils.rm_rf(absolute_output)
      FileUtils.mkdir_p(absolute_output)
      error = assert_raises(Lambda::MicroVMs::CommandError) do
        Lambda::MicroVMs::Packager.new(project).package(output: absolute_output)
      end
      assert_match(/zip failed:/, error.message)

      original_capture3 = Open3.method(:capture3)
      failed_status = Struct.new(:success?).new(false)
      Open3.define_singleton_method(:capture3) { |*_args, **_kwargs| ['stdout text', 'stderr text', failed_status] }
      error = assert_raises(Lambda::MicroVMs::CommandError) do
        Lambda::MicroVMs::Packager.new(project).package(output: File.join(dir, 'stubbed.zip'))
      end
      assert_equal 'zip failed: stderr text', error.message
      Open3.define_singleton_method(:capture3, original_capture3)
    end
  end

  def test_doctor_private_checks_cover_success_and_failure_shapes
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), <<~YAML)
        name: demo
        role_arn: arn:role
        deployment:
          bucket: bucket
        build:
          dockerfile: Dockerfile
      YAML
      File.write(File.join(dir, 'Dockerfile'), "FROM ruby\n")
      File.write(File.join(dir, 'Gemfile'), "gem 'aws_lambda_ric'\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
      doctor = Lambda::MicroVMs::Doctor.new(project: project)

      assert doctor.send(:command_check, 'Ruby true', %(ruby -e 'exit 0')).ok
      refute doctor.send(:command_check, 'Ruby false', %(ruby -e 'exit 1')).ok
      assert doctor.send(:file_check, 'Dockerfile', project.dockerfile).ok
      assert doctor.send(:config_check, 'role_arn', project.role_arn).ok
      assert doctor.send(:ric_check).ok
      refute_nil doctor.checks.find { |check| check.name == 'Ruby' }
      refute_nil doctor.ok?

      File.write(File.join(dir, 'Gemfile'), "gem 'json'\n")
      refute doctor.send(:ric_check).ok
      FileUtils.rm_f(File.join(dir, 'Gemfile'))
      refute doctor.send(:ric_check).ok
    end
  end


  def test_remaining_branch_shapes
    assert_nil Lambda::MicroVMs::Util.extract(Object.new, :missing)

    sdk = FakeSdk.new
    vm = Lambda::MicroVMs::MicroVM.new(client: Lambda::MicroVMs::Client.new(sdk: sdk), id: 'vm-1')
    assert_equal 'token-1', vm.auth_token

    nil_resume_client = Object.new
    def nil_resume_client.resume_microvm(**_params) = nil
    vm = Lambda::MicroVMs::MicroVM.new(client: nil_resume_client, id: 'vm-1', data: { state: 'suspended' })
    assert_same vm, vm.resume
    assert_predicate vm, :suspended?

    boom_client = Object.new
    def boom_client.image(_arn) = raise 'run failed'
    assert_raises(RuntimeError) do
      Lambda::MicroVMs.session(image_arn: 'image-1', role_arn: 'role-1', client: boom_client) { |_vm| }
    end

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), "name: demo\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
      assert_equal({}, project.run_params)
      assert_equal 'relative.zip', Lambda::MicroVMs::Packager.new(project).package(output: 'relative.zip')
      FileUtils.rm_f(File.join(dir, 'relative.zip'))

      doctor = Lambda::MicroVMs::Doctor.new(project: project)
      bad_command = Object.new
      def bad_command.to_s = raise 'bad command'
      refute doctor.send(:command_check, 'bad command', bad_command).ok
    end
  end

  private

  def with_aws_constant(service, client_class)
    original_aws_defined = Object.const_defined?(:Aws, false)
    original_aws = Object.const_get(:Aws) if original_aws_defined
    Object.send(:remove_const, :Aws) if original_aws_defined

    service_module = Module.new
    service_module.const_set(:Client, client_class)
    aws = Module.new
    aws.const_set(service, service_module)
    Object.const_set(:Aws, aws)
    yield
  ensure
    Object.send(:remove_const, :Aws) if Object.const_defined?(:Aws, false)
    Object.const_set(:Aws, original_aws) if original_aws_defined
  end

  def without_aws_constant(service)
    original_aws_defined = Object.const_defined?(:Aws, false)
    original_aws = Object.const_get(:Aws) if original_aws_defined
    Object.send(:remove_const, :Aws) if original_aws_defined

    other_service = service == :S3 ? :Lambda : :S3
    aws = Module.new
    aws.const_set(other_service, Module.new)
    Object.const_set(:Aws, aws)
    yield
  ensure
    Object.send(:remove_const, :Aws) if Object.const_defined?(:Aws, false)
    Object.const_set(:Aws, original_aws) if original_aws_defined
  end

end
