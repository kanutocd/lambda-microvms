# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class DeployerTest < Minitest::Test
  FakeS3 = Struct.new(:calls, keyword_init: true) do
    def put_object(**params)
      calls << params
    end
  end

  FakeClient = Struct.new(:images, keyword_init: true) do
    def create_image(**params)
      images << params
      Lambda::MicroVMs::Image.new(client: self, arn: 'arn:image', data: params)
    end
  end

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def test_deploy_packages_uploads_and_creates_image
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), <<~YAML)
        name: demo
        deployment:
          bucket: bucket-name
        image:
          create:
            base_image_arn: arn:base
      YAML
      File.write(File.join(dir, 'app.rb'), "puts :ok\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
      s3 = FakeS3.new(calls: [])
      client = FakeClient.new(images: [])

      image = Lambda::MicroVMs::Deployer.new(project: project, client: client, s3: s3).deploy

      assert_equal 'arn:image', image.arn
      assert_equal 'bucket-name', s3.calls.first.fetch(:bucket)
      assert_equal 'arn:base', client.images.first.fetch(:base_image_arn)
      assert_match %r{\As3://bucket-name/}, client.images.first.fetch(:code_artifact)
    end
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize
end
