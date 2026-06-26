# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class DeployerTest < Minitest::Test
  FakeS3 = Struct.new(:calls, :body, keyword_init: true) do
    def put_object(**params)
      self.body = params.fetch(:body)
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

  def test_upload_closes_artifact_file
    project = project_from("name: demo\ndeployment:\n  bucket: bucket-name\n")
    path = File.join(project.root, 'artifact.zip')
    File.write(path, 'artifact')
    s3 = FakeS3.new(calls: [])

    Lambda::MicroVMs::Deployer.new(project: project, client: Object.new, s3: s3).upload(path)

    assert_predicate s3.body, :closed?
  end

  def test_run_uses_configured_image_and_role
    image = FakeImage.new(runs: [])
    client = FakeRunClient.new(image_resource: image)
    project = project_from(<<~YAML)
      name: demo
      role_arn: arn:role
      image:
        arn: arn:image
      runtime:
        run:
          memory_size: 512
    YAML

    vm = Lambda::MicroVMs::Deployer.new(project: project, client: client, s3: Object.new).run

    assert_equal 'vm-run', vm.id
    assert_equal({ memory_size: 512, role_arn: 'arn:role' }, image.runs.first)
  end

  def test_builds_default_s3_client_with_options
    project = project_from("name: demo\nregion: us-east-1\nprofile: dev\n")

    with_aws_constant(:S3, FakeAwsClient) do
      assert_equal({ region: 'us-east-1', profile: 'dev' }, default_s3(project).args)
    end
  end

  def test_builds_default_s3_client_without_options
    project = project_from("name: demo\n")

    with_aws_constant(:S3, FakeAwsClient) do
      assert_equal({}, default_s3(project).args)
    end
  end

  def test_raises_when_s3_sdk_is_missing
    without_aws_constant(:S3) do
      assert_raises(LoadError) { Lambda::MicroVMs::Deployer.new(project: project_from("name: demo\n"), client: Object.new) }
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

  FakeAwsClient = Class.new do
    attr_reader :args

    def initialize(**args)
      @args = args
    end
  end

  private

  def default_s3(project)
    Lambda::MicroVMs::Deployer.new(project: project, client: Object.new).s3
  end

  def project_from(yaml)
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'microvm.yml'), yaml)
    Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
  end
end
