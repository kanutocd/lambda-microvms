# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class ScaffoldTest < Minitest::Test
  def test_creates_ruby_microvm_project
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'worker')
      Lambda::MicroVMs::Scaffold.new('worker', directory: path).create

      assert_path_exists File.join(path, 'Dockerfile')
      assert_includes File.read(File.join(path, 'Gemfile')), 'aws_lambda_ric'
      assert_includes File.read(File.join(path, 'app.rb')), 'class Handler'
      assert_includes File.read(File.join(path, 'microvm.yml')), 'deployment:'
    end
  end

  def test_refuses_non_empty_directory_without_force
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'existing'), 'x')
      assert_raises(Lambda::MicroVMs::ConfigurationError) do
        Lambda::MicroVMs::Scaffold.new('worker', directory: dir).create
      end
    end
  end
end
