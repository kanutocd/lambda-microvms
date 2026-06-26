# Changelog

## Unreleased

## 0.2.0

- Added `lambda-microvms sdk-contract` and doctor output for the experimental MicroVM SDK operation contract.
- Added an adapter boundary for MicroVM SDK operations.
- Added `Lambda::MicroVMs::FunctionClient` and `lambda-microvms function-invoke` for standard Lambda function APIs.
- Made MicroVM deploy/run fail before packaging or uploading when the installed `aws-sdk-lambda` lacks MicroVM operations.

## 0.1.0

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
