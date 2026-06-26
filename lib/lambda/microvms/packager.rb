# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'pathname'

module Lambda
  module MicroVMs
    # Creates a deployable source artifact for Lambda MicroVM image creation.
    class Packager
      DEFAULT_EXCLUDES = ['.git/*', 'tmp/*', 'vendor/bundle/*', '*.gem'].freeze

      attr_reader :project

      def initialize(project)
        @project = project
      end

      def package(output: project.artifact_path)
        FileUtils.mkdir_p(File.dirname(output))
        relative_output = begin
          Pathname.new(output).relative_path_from(Pathname.new(project.root)).to_s
        rescue StandardError
          output
        end
        excludes = DEFAULT_EXCLUDES + [relative_output]
        command = ['zip', '-q', '-r', output, '.'] + excludes.flat_map { |pattern| ['-x', pattern] }
        stdout, stderr, status = Open3.capture3(*command, chdir: project.root)
        raise CommandError, "zip failed: #{stderr.empty? ? stdout : stderr}" unless status.success?

        output
      end
    end
  end
end
