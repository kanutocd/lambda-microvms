# frozen_string_literal: true

require 'securerandom'

begin
  require 'aws-sdk-s3'
rescue LoadError
  nil
end

module Lambda
  module MicroVMs
    # Project-aware deployment helper: package, upload to S3, create MicroVM image.
    class Deployer
      attr_reader :project, :client, :s3

      def initialize(project:, client: nil, s3: nil) # rubocop:disable Naming/MethodParameterName
        @project = project
        @client = client || Client.new(region: project.region, profile: project.profile)
        @s3 = s3 || build_s3
      end

      # Package the project into a deployable zip artifact.
      #
      # @return [String] artifact path
      def package
        Packager.new(project).package
      end

      # Upload an artifact to the configured S3 bucket and prefix.
      #
      # @param path [String] local artifact path
      # @return [String] S3 URI
      def upload(path)
        bucket = project.require!('deployment.bucket', project.s3_bucket)
        key = [project.s3_prefix.sub(%r{/\z}, ''), File.basename(path)].join('/')
        s3.put_object(bucket: bucket, key: key, body: File.open(path, 'rb'))
        "s3://#{bucket}/#{key}"
      end

      # Package, upload, and create a MicroVM image.
      #
      # @return [Image] created image resource
      def deploy
        artifact = package
        artifact_uri = upload(artifact)
        client.create_image(**project.create_image_params(artifact_uri: artifact_uri))
      end

      # Run the configured image with configured runtime parameters.
      #
      # @return [MicroVM] started MicroVM resource
      def run
        image_arn = project.require!('image.arn', project.image_arn)
        role_arn = project.require!('role_arn', project.role_arn)
        client.image(image_arn).run(**project.run_params, role_arn: role_arn)
      end

      private

      def build_s3
        raise LoadError, 'install aws-sdk-s3 to use deployment helpers' unless defined?(Aws::S3::Client)

        args = {}
        args[:region] = project.region if project.region
        args[:profile] = project.profile if project.profile
        Aws::S3::Client.new(**args)
      end
    end
  end
end
