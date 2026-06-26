# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'test_helper'

class CLITest < Minitest::Test
  def test_version_command
    stdout, stderr, status = run_cli('version')

    assert_equal "#{Lambda::MicroVMs::VERSION}\n", stdout
    assert_empty stderr
    assert_predicate status, :success?
  end

  def test_unknown_command_exits_with_error
    stdout, stderr, status = run_cli('nope')

    assert_match(/Commands:/, stdout)
    assert_match(/unknown command: nope/, stderr)
    refute_predicate status, :success?
  end

  def test_sdk_contract_reports_missing_operations
    stdout, stderr, status = run_cli('sdk-contract')

    if status.success?
      assert_match(/exposes all Lambda MicroVM operations/, stdout)
    else
      assert_match(/missing Aws::Lambda::Client operations:/, stderr)
    end
  end

  private

  def run_cli(*)
    env = { 'RUBYLIB' => File.expand_path('../lib', __dir__) }
    exe = File.expand_path('../exe/lambda-microvms', __dir__)
    Open3.capture3(env, RbConfig.ruby, exe, *)
  end
end
