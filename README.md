# lambda-microvms

[![Gem Version](https://badge.fury.io/rb/lambda-microvms.svg)](https://badge.fury.io/rb/lambda-microvms)
[![CI](https://github.com/kanutocd/lambda-microvms/workflows/CI/badge.svg)](https://github.com/kanutocd/lambda-microvms/actions)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.2-ruby.svg)](https://www.ruby-lang.org/en/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Ruby development kit for AWS Lambda MicroVMs.

`lambda-microvms` builds on the official `aws-sdk-lambda` gem. It provides Ruby resource objects, lifecycle helpers, endpoint calls, project scaffolding, packaging, and deployment commands for Lambda MicroVM applications.

It gives Ruby developers a higher-level workflow:

```text
scaffold
  ↓
develop
  ↓
package
  ↓
deploy image
  ↓
run / suspend / resume / terminate
```

## Why `aws_lambda_ric` appears in generated projects

Ruby MicroVM applications need a runtime inside the image. For non-AWS or OS-only Ruby container images, AWS documents the Ruby Runtime Interface Client (`aws_lambda_ric`) as the component that lets Ruby code interact with the Lambda Runtime API.

`lambda-microvms` uses `aws_lambda_ric` as a **generated project dependency**, not as a host-side SDK dependency.

```text
Host side:
  lambda-microvms
  aws-sdk-lambda
  aws-sdk-s3

Guest side / inside generated image:
  aws_lambda_ric
  your Ruby handler
```

## Installation

```ruby
gem "lambda-microvms"
```

## Scaffold a Ruby MicroVM project

```bash
lambda-microvms new hello-worker
cd hello-worker
```

Generated project:

```text
hello-worker/
  Dockerfile
  Gemfile
  app.rb
  microvm.yml
  README.md
  .env.example
```

The generated `Gemfile` includes:

```ruby
gem "aws_lambda_ric"
```

## Check readiness

```bash
lambda-microvms doctor
```

Checks Ruby, Docker, AWS CLI, project config, Dockerfile, deployment bucket, runtime role, and `aws_lambda_ric` presence.

## Package

```bash
lambda-microvms package
```

Creates the source artifact configured by `microvm.yml`.

## Deploy

```bash
lambda-microvms deploy
```

Deployment flow:

```text
zip project
  ↓
upload to S3
  ↓
create MicroVM image through aws-sdk-lambda
```

The exact AWS Lambda MicroVM API parameter names are still kept close to AWS naming. Put API-specific values under `image.create` in `microvm.yml`.

## Run

```bash
lambda-microvms run
```

Runs the configured image ARN with the configured role ARN and runtime payload.

## Ruby SDK usage

```ruby
require "lambda/microvms"

client = Lambda::MicroVMs::Client.new(region: "us-east-1")

image = client.image("arn:aws:lambda:us-east-1:123456789012:microvm-image:ruby-sandbox")

vm = image.run(
  role_arn: "arn:aws:iam::123456789012:role/lambda-microvm-runtime",
  payload: { tenant_id: "tenant_123" }
)

vm.wait_until_running

response = vm.post("/process", json: { hello: "world" })

vm.suspend
vm.resume
vm.terminate
```

## Session helper

```ruby
Lambda::MicroVMs.session(
  image_arn: "arn:aws:lambda:us-east-1:123456789012:microvm-image:ruby-sandbox",
  role_arn: "arn:aws:iam::123456789012:role/lambda-microvm-runtime",
  after: :suspend,
  payload: { tenant_id: "tenant_123" }
) do |vm|
  vm.post("/process", json: { event_id: "evt_1" })
end
```

Supported cleanup policies:

```ruby
after: :keep
after: :suspend
after: :terminate
```

## Architecture

```text
aws-sdk-lambda
        │
        ▼
Lambda::MicroVMs::Client
        │
        ├── Image
        ├── MicroVM
        ├── Endpoint
        ├── Session
        ├── Scaffold
        ├── Packager
        └── Deployer
```

## Status

This is an early implementation. Lambda MicroVMs is new, so generated AWS SDK operation shapes may evolve. Unsupported low-level operations raise `Lambda::MicroVMs::UnsupportedOperationError` with an upgrade hint.
give