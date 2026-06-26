# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class DoctorTest < Minitest::Test
  def test_command_and_file_checks
    doctor = Lambda::MicroVMs::Doctor.new(project: project_with_ric)

    assert doctor.send(:command_check, 'Ruby true', %(ruby -e 'exit 0')).ok
    refute doctor.send(:command_check, 'Ruby false', %(ruby -e 'exit 1')).ok
    assert doctor.send(:file_check, 'Dockerfile', doctor.project.dockerfile).ok
  end

  def test_config_and_ric_checks
    doctor = Lambda::MicroVMs::Doctor.new(project: project_with_ric)

    assert doctor.send(:config_check, 'role_arn', doctor.project.role_arn).ok
    assert doctor.send(:ric_check).ok
  end

  def test_checks_and_ok_return_statuses
    doctor = Lambda::MicroVMs::Doctor.new(project: project_with_ric)

    refute_nil(doctor.checks.find { |check| check.name == 'Ruby' })
    refute_nil doctor.ok?
  end

  def test_ric_check_fails_when_gemfile_is_missing_or_missing_ric
    Dir.mktmpdir do |dir|
      project = write_project(dir)
      doctor = Lambda::MicroVMs::Doctor.new(project: project)

      File.write(File.join(dir, 'Gemfile'), "gem 'json'\n")

      refute doctor.send(:ric_check).ok
      FileUtils.rm_f(File.join(dir, 'Gemfile'))

      refute doctor.send(:ric_check).ok
    end
  end

  def test_config_check_rejects_blank_string
    doctor = Lambda::MicroVMs::Doctor.new(project: project_with_ric)

    refute doctor.send(:config_check, 'role_arn', '  ').ok
  end

  def test_command_check_handles_command_coercion_errors
    doctor = Lambda::MicroVMs::Doctor.new(project: project_with_ric)
    bad_command = Object.new
    def bad_command.to_s = raise 'bad command'

    refute doctor.send(:command_check, 'bad command', bad_command).ok
  end

  private

  def project_with_ric
    dir = Dir.mktmpdir
    project = write_project(dir)
    File.write(File.join(dir, 'Gemfile'), "gem 'aws_lambda_ric'\n")
    project
  end

  def write_project(dir)
    File.write(File.join(dir, 'microvm.yml'), <<~YAML)
      name: demo
      role_arn: arn:role
      deployment:
        bucket: bucket
      build:
        dockerfile: Dockerfile
    YAML
    File.write(File.join(dir, 'Dockerfile'), "FROM ruby\n")
    Lambda::MicroVMs::Project.load(File.join(dir, 'microvm.yml'))
  end
end
