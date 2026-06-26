# frozen_string_literal: true

require 'English'
module Lambda
  module MicroVMs
    # Performs lightweight local project readiness checks.
    class Doctor
      Check = Struct.new(:name, :ok, :detail, keyword_init: true)

      attr_reader :project, :runner

      def initialize(project:, runner: Kernel)
        @project = project
        @runner = runner
      end

      def checks
        [
          check('Ruby', RUBY_VERSION >= '3.2', RUBY_VERSION),
          command_check('Docker', 'docker --version'),
          command_check('AWS CLI', 'aws --version'),
          file_check('microvm.yml', project.config_path),
          file_check('Dockerfile', project.dockerfile),
          config_check('role_arn', project.role_arn),
          config_check('deployment.bucket', project.s3_bucket),
          ric_check
        ]
      end

      def ok?
        checks.all?(&:ok)
      end

      private

      def check(name, ok, detail) # rubocop:disable Naming/MethodParameterName
        Check.new(name:, ok:, detail: detail.to_s)
      end

      def command_check(name, command)
        output = `#{command} 2>&1`.strip
        Check.new(name:, ok: $CHILD_STATUS.success?, detail: output)
      rescue StandardError => e
        Check.new(name:, ok: false, detail: e.message)
      end

      def file_check(name, path)
        Check.new(name:, ok: File.exist?(path), detail: path)
      end

      def config_check(name, value)
        Check.new(name:, ok: value && value != '', detail: value || 'missing')
      end

      def ric_check
        gemfile = File.join(project.root, 'Gemfile')
        ok = File.exist?(gemfile) && File.read(gemfile).include?('aws_lambda_ric')
        Check.new(name: 'aws_lambda_ric', ok: ok, detail: ok ? 'present in Gemfile' : 'missing from Gemfile')
      end
    end
  end
end
