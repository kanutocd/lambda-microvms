# Changelog

## 0.1.0 Unreleased

- Initial Ruby development kit for AWS Lambda MicroVMs.
- Client wrapper over `aws-sdk-lambda`.
- Image, MicroVM, Endpoint, Waiter, and session helper APIs.
- Project scaffolding via `lambda-microvms new NAME`.
- Generated Ruby MicroVM projects include `aws_lambda_ric` for guest-side Lambda Runtime API integration.
- Project configuration via `microvm.yml`.
- Packaging helper via `lambda-microvms package`.
- Deployment helper via `lambda-microvms deploy` using S3 artifact upload and MicroVM image creation.
- Runtime helper via `lambda-microvms run`.
- Project readiness checks via `lambda-microvms doctor`.
