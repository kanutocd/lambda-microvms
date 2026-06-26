# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class ProjectTest < Minitest::Test
  def test_loads_project_configuration
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), <<~YAML)
        name: demo
        region: us-east-1
        role_arn: arn:role
        deployment:
          bucket: bucket-name
        image:
          arn: arn:image
      YAML

      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      assert_equal 'demo', project.name
      assert_equal 'us-east-1', project.region
      assert_equal 'arn:role', project.role_arn
      assert_equal 'bucket-name', project.s3_bucket
      assert_equal 'arn:image', project.image_arn
    end
  end

  def test_create_image_params_injects_artifact_uri
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), <<~YAML)
        name: demo
        image:
          create:
            base_image_arn: arn:base
      YAML
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      assert_equal({ base_image_arn: 'arn:base', name: 'demo', code_artifact: 's3://bucket/key.zip' },
                   project.create_image_params(artifact_uri: 's3://bucket/key.zip'))
    end
  end

  def test_payload_and_run_params_stringify_nested_values
    project = project_from(<<~YAML)
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

    assert_equal({ 'tenant' => 't1' }, project.payload)
    assert_equal({ environment: [{ 'name' => 'A', 'value' => 'B' }], role_arn: 'arn:role',
                   payload: { 'tenant' => 't1' } }, project.run_params)
  end

  def test_run_params_preserve_explicit_role_and_empty_payload
    project = project_from(<<~YAML)
      name: demo
      role_arn: arn:role
      runtime:
        payload:
        run:
          role_arn: explicit-role
          payload: {}
    YAML

    assert_equal({}, project.payload)
    assert_equal({ role_arn: 'explicit-role', payload: {} }, project.run_params)
  end

  def test_run_params_allow_missing_role_when_not_required_yet
    project = project_from("name: demo\n")

    assert_equal({}, project.run_params)
  end

  def test_require_rejects_blank_strings
    project = project_from("name: demo\n")

    assert_equal 'x', project.require!('x', 'x')
    assert_raises(Lambda::MicroVMs::ConfigurationError) { project.require!('missing', '  ') }
  end

  def test_validate_rejects_unknown_lifecycle_policy
    project = project_from("name: demo\nruntime:\n  after: explode\n")

    error = assert_raises(Lambda::MicroVMs::ConfigurationError) { project.validate! }

    assert_match(/unsupported runtime.after/, error.message)
  end

  def test_validate_rejects_non_hash_sections
    project = project_from("name: demo\nruntime:\n  payload: nope\n")

    error = assert_raises(Lambda::MicroVMs::ConfigurationError) { project.validate! }

    assert_equal 'runtime.payload must be a mapping', error.message
  end

  def test_load_rejects_non_mapping_yaml
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), "--- nope\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      assert_raises(Lambda::MicroVMs::ConfigurationError) { project.validate! }
    end
  end

  private

  def project_from(yaml)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), yaml)
      return Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
    end
  end
end
