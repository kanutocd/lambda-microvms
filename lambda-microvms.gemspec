# frozen_string_literal: true

require_relative 'lib/lambda/microvms/version'

Gem::Specification.new do |spec|
  spec.name = 'lambda-microvms'
  spec.version = Lambda::MicroVMs::VERSION
  spec.authors = ['Kenneth C. Demanawa']
  spec.email = ['kenneth.c.demanawa@gmail.com']

  spec.summary = 'Idiomatic Ruby lifecycle client for AWS Lambda MicroVMs.'
  spec.description = <<~DESC
    Ruby resource objects, waiters, endpoint helpers, project scaffolding, packaging,#{' '}
    and deployment ergonomics built on top of aws-sdk-lambda.
  DESC

  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'
  spec.homepage = 'https://kanutocd.github.io/lambda-microvms/'
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['documentation_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/kanutocd/lambda-microvms'
  spec.metadata['changelog_uri'] = "#{spec.metadata['source_code_uri']}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir['lib/**/*.rb', 'sig/**/*.rbs', 'exe/*', 'README.md', 'LICENSE.txt', 'CHANGELOG.md', 'SKETCHES.md']
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |file| File.basename(file) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-lambda', '~> 1.185'
  spec.add_dependency 'aws-sdk-s3', '~> 1.226'
  spec.add_dependency 'json', '~> 2.20'
end
