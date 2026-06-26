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

  def test_returns_explicit_output
    Dir.mktmpdir do |dir|
      project = write_project(dir)
      output = File.join(Dir.mktmpdir, 'artifact.zip')

      assert_equal output, Lambda::MicroVMs::Packager.new(project).package(output: output)
    end
  end

  def test_raises_when_output_path_is_directory
    Dir.mktmpdir do |dir|
      project = write_project(dir)
      output = File.join(Dir.mktmpdir, 'artifact.zip')
      FileUtils.mkdir_p(output)

      error = assert_raises(Lambda::MicroVMs::CommandError) { Lambda::MicroVMs::Packager.new(project).package(output: output) }

      assert_match(/zip failed:/, error.message)
    end
  end

  def test_raises_with_stderr_when_zip_command_fails
    Dir.mktmpdir do |dir|
      project = write_project(dir)
      error =
        assert_raises(Lambda::MicroVMs::CommandError) do
          failed_packager(project).package(output: File.join(dir, 'stubbed.zip'))
        end

      assert_equal 'zip failed: stderr text', error.message
    end
  end

  def test_relative_output_path
    Dir.mktmpdir do |dir|
      project = write_project(dir)

      assert_equal 'relative.zip', Lambda::MicroVMs::Packager.new(project).package(output: 'relative.zip')
      FileUtils.rm_f(File.join(dir, 'relative.zip'))
    end
  end

  private

  def write_project(dir)
    File.write(File.join(dir, 'microvm.yml'), "name: demo\n")
    File.write(File.join(dir, 'app.rb'), "puts :ok\n")
    Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
  end

  def failed_packager(project)
    status = Struct.new(:success?).new(false)
    runner = Struct.new(:status) do
      def capture3(*, **)
        ['stdout text', 'stderr text', status]
      end
    end
    Lambda::MicroVMs::Packager.new(project, runner: runner.new(status))
  end
end
