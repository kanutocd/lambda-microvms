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
end
