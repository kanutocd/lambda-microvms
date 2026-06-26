# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class PackagerTest < Minitest::Test
  def test_packages_project_files
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'microvm.yml'), "name: demo\n")
      File.write(File.join(dir, 'app.rb'), "puts :ok\n")
      project = Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))

      output = Lambda::MicroVMs::Packager.new(project).package

      assert_path_exists output
      names = `unzip -Z1 #{output}`.split("\n")

      assert_includes names, 'app.rb'
      assert_includes names, 'microvm.yml'
    end
  end
end
