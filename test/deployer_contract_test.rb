# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class DeployerContractTest < Minitest::Test
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

  FakeImage = Struct.new(:runs, keyword_init: true) do
    def run(**params)
      runs << params
      Lambda::MicroVMs::MicroVM.new(client: Object.new, id: 'vm-run')
    end
  end

  def test_deploy_fails_before_packaging_when_microvm_contract_is_missing
    project = project_from("name: demo\ndeployment:\n  bucket: bucket-name\n")
    client = Lambda::MicroVMs::Client.new(sdk: Object.new)
    deployer = Lambda::MicroVMs::Deployer.new(project: project, client: client, s3: Object.new)

    error = assert_raises(Lambda::MicroVMs::UnsupportedOperationError) { deployer.deploy }

    assert_match(/missing MicroVM operations/, error.message)
  end

  def test_deploy_skips_contract_guard_for_custom_clients
    project = project_from("name: demo\ndeployment:\n  bucket: bucket-name\n")
    File.write(File.join(project.root, 'app.rb'), "puts :ok\n")

    image = Lambda::MicroVMs::Deployer.new(project: project, client: FakeClient.new(images: []),
                                           s3: FakeS3.new(calls: [])).deploy

    assert_equal 'arn:image', image.arn
  end

  def test_run_continues_when_client_adapter_contract_is_supported
    adapter = Struct.new(:unsupported_operations).new([])
    image = FakeImage.new(runs: [])
    client = Struct.new(:adapter, :image_resource) do
      def image(_arn) = image_resource
    end.new(adapter, image)
    project = project_from("name: demo\nrole_arn: arn:role\nimage:\n  arn: arn:image\n")

    vm = Lambda::MicroVMs::Deployer.new(project: project, client: client, s3: Object.new).run

    assert_equal 'vm-run', vm.id
  end

  private

  def project_from(yaml)
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'microvm.yml'), yaml)
    Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
  end
end
