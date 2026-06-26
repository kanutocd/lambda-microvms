# frozen_string_literal: true

require 'coverage'
Coverage.start(lines: true, branches: true)

require 'minitest/autorun'
require_relative '../lib/lambda/microvms'

Minitest.after_run do
  result = Coverage.result
  project = File.expand_path('..', __dir__)
  lib = File.join(project, 'lib')
  files = result.select { |path, _coverage| path.start_with?(lib) && path.end_with?('.rb') }

  line_total = 0
  line_hit = 0
  branch_total = 0
  branch_hit = 0

  files.each_value do |coverage|
    coverage.fetch(:lines).each do |count|
      next if count.nil?

      line_total += 1
      line_hit += 1 if count.positive?
    end

    coverage.fetch(:branches, {}).each_value do |branches|
      branches.each_value do |count|
        branch_total += 1
        branch_hit += 1 if count.positive?
      end
    end
  end

  line_percent = line_total.zero? ? 100.0 : (line_hit.to_f / line_total * 100)
  branch_percent = branch_total.zero? ? 100.0 : (branch_hit.to_f / branch_total * 100)

  puts format('Line Coverage: %<percent>.2f%% (%<hit>d/%<total>d)', percent: line_percent, hit: line_hit,
                                                                    total: line_total)
  puts format('Branch Coverage: %<percent>.2f%% (%<hit>d/%<total>d)', percent: branch_percent, hit: branch_hit,
                                                                      total: branch_total)

  if ENV['SHOW_MISSING_COVERAGE'] == 'true'
    files.each do |path, coverage|
      lines = File.readlines(path)
      coverage.fetch(:lines).each_with_index do |count, index|
        next if count.nil? || count.positive?

        puts "MISS #{path}:#{index + 1}: #{lines[index]&.strip}"
      end
      coverage.fetch(:branches, {}).each do |branch, branches|
        branches.each do |kind, count|
          puts "BRANCH MISS #{path}: #{branch.inspect} #{kind.inspect}" if count.zero?
        end
      end
    end
  end

  if ENV['ENFORCE_COVERAGE'] != 'false'
    raise 'line coverage below 99%' unless line_percent > 99.0
    raise 'branch coverage below 99%' unless branch_percent > 99.0
  end
end

class FakeSdk
  attr_reader :calls

  def initialize
    @calls = []
    @microvm_states = [:running]
    @image_states = [:ready]
  end

  attr_writer :microvm_states, :image_states

  def create_microvm_image(**params)
    record(:create_microvm_image, params)
    { image_arn: 'image-1', state: 'READY' }
  end

  def get_microvm_image(**params)
    record(:get_microvm_image, params)
    { image_arn: params.fetch(:image_arn), state: @image_states.shift || :ready }
  end

  def run_microvm(**params)
    record(:run_microvm, params)
    { microvm_id: 'vm-1', state: 'PENDING', endpoint_url: 'https://example.test' }
  end

  def get_microvm(**params)
    record(:get_microvm, params)
    {
      microvm_id: params.fetch(:microvm_id),
      state: @microvm_states.shift || :running,
      endpoint_url: 'https://example.test'
    }
  end

  def create_microvm_auth_token(**params)
    record(:create_microvm_auth_token, params)
    { token: 'token-1' }
  end

  def delete_microvm_image(**params)
    record(:delete_microvm_image, params)
    { deleted: true }
  end

  def list_microvms(**params)
    record(:list_microvms, params)
    { microvms: [] }
  end

  def suspend_microvm(**params)
    record(:suspend_microvm, params)
    { state: 'SUSPENDING' }
  end

  def resume_microvm(**params)
    record(:resume_microvm, params)
    { microvm_id: params.fetch(:microvm_id), state: 'RUNNING' }
  end

  def terminate_microvm(**params)
    record(:terminate_microvm, params)
    { state: 'TERMINATING' }
  end

  private

  def record(name, params)
    @calls << [name, params]
  end
end
