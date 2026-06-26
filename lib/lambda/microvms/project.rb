# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'tmpdir'

module Lambda
  module MicroVMs
    # Reads lambda-microvms project configuration from microvm.yml.
    class Project
      # Default project configuration file name.
      DEFAULT_CONFIG = 'microvm.yml'

      attr_reader :root, :config_path, :config

      # Load a project configuration from disk.
      #
      # @param path [String] path to a YAML configuration file
      # @return [Project] loaded project
      def self.load(path = DEFAULT_CONFIG)
        config_path = File.expand_path(path)
        root = File.dirname(config_path)
        new(root: root, config_path: config_path,
            config: YAML.safe_load_file(config_path, permitted_classes: [Symbol], aliases: true) || {})
      end

      def initialize(root:, config_path:, config:)
        @root = root
        @config_path = config_path
        @config = stringify_keys(config)
      end

      # Project name.
      #
      # @return [String]
      def name = fetch('name', default: File.basename(root))

      # AWS region from configuration or environment.
      #
      # @return [String, nil]
      def region = fetch('region', default: ENV.fetch('AWS_REGION', nil))

      # AWS profile from configuration or environment.
      #
      # @return [String, nil]
      def profile = fetch('profile', default: ENV.fetch('AWS_PROFILE', nil))

      # IAM role ARN used when running MicroVMs.
      #
      # @return [String, nil]
      def role_arn = fetch('role_arn', 'role', default: nil)

      # Existing MicroVM image ARN.
      #
      # @return [String, nil]
      def image_arn = fetch('image_arn', 'image.arn', default: nil)

      # Name used when creating a MicroVM image.
      #
      # @return [String]
      def image_name = fetch('image.name', default: name)

      # Absolute path to the Dockerfile.
      #
      # @return [String]
      def dockerfile = File.expand_path(fetch('build.dockerfile', default: 'Dockerfile'), root)

      # Absolute path to the build context.
      #
      # @return [String]
      def build_context = File.expand_path(fetch('build.context', default: '.'), root)

      # Absolute path for the packaged artifact.
      #
      # @return [String]
      def artifact_path = File.expand_path(fetch('build.artifact', default: "tmp/#{name}-microvm.zip"), root)

      # S3 bucket used for deployment artifacts.
      #
      # @return [String, nil]
      def s3_bucket = fetch('deployment.bucket', 's3.bucket', default: nil)

      # S3 key prefix used for deployment artifacts.
      #
      # @return [String]
      def s3_prefix = fetch('deployment.prefix', 's3.prefix', default: "lambda-microvms/#{name}")

      # Cleanup policy used after a session block.
      #
      # @return [Symbol]
      def lifecycle_after = fetch('runtime.after', default: 'suspend').to_sym

      # Runtime payload configured for MicroVM runs.
      #
      # @return [Hash]
      def payload
        fetch('runtime.payload', default: {}) || {}
      end

      # Build parameters for image creation with the artifact URI injected.
      #
      # @param artifact_uri [String] uploaded artifact URI
      # @return [Hash] SDK-style create image parameters
      def create_image_params(artifact_uri:)
        params = fetch('image.create', default: {}) || {}
        params = stringify_keys(params)
        symbolized = params.to_h { |key, value| [key.to_sym, value] }
        symbolized[:name] ||= image_name
        symbolized[:code_artifact] ||= artifact_uri
        symbolized
      end

      # Build parameters for running a MicroVM.
      #
      # @return [Hash] SDK-style run parameters
      def run_params
        params = stringify_keys(fetch('runtime.run', default: {}) || {})
        symbolized = params.to_h { |key, value| [key.to_sym, value] }
        symbolized[:role_arn] ||= role_arn if role_arn
        symbolized[:payload] ||= payload unless payload.empty?
        symbolized
      end

      # Return a required value or raise a configuration error.
      #
      # @param field [String] configuration field name used in the error
      # @param value [Object] value to validate
      # @return [Object] the validated value
      # @raise [ConfigurationError] when the value is nil or empty
      def require!(field, value)
        return value if value && value != ''

        raise ConfigurationError, "missing required project configuration: #{field}"
      end

      private

      def fetch(*paths, default:)
        paths.each do |path|
          current = @config
          path.to_s.split('.').each do |part|
            current = current[part] if current.respond_to?(:[])
          end
          return current unless current.nil?
        end
        default
      end

      def stringify_keys(value)
        case value
        when Hash
          value.to_h { |key, child| [key.to_s, stringify_keys(child)] }
        when Array
          value.map { |child| stringify_keys(child) }
        else
          value
        end
      end
    end
  end
end
