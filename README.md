# Serverless HR Lookup Application

Assignment 2 implementation using API Gateway REST API, Lambda, DynamoDB,
Cognito Managed Login, and IAM.

## Deploy

Prerequisites: Terraform, AWS CLI, and the `hrishi-developer` AWS profile.

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_PROFILE=hrishi-developer
aws sts get-caller-identity

cd infra
cp terraform.tfvars.example terraform.tfvars
# Set a unique Cognito domain prefix and the student's full name.
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

The student IAM user ARN is:

```text
arn:aws:iam::451789368151:user/hrishi-developer
```

## Create the Cognito test user

Run from `infra/`. The password is read without displaying or saving it:

```bash
read -s COGNITO_PASSWORD
POOL_ID="$(terraform output -raw cognito_user_pool_id)"
aws cognito-idp admin-create-user \
  --user-pool-id "$POOL_ID" \
  --username student \
  --message-action SUPPRESS \
  --temporary-password "$COGNITO_PASSWORD"
aws cognito-idp admin-set-user-password \
  --user-pool-id "$POOL_ID" \
  --username student \
  --password "$COGNITO_PASSWORD" \
  --permanent
unset COGNITO_PASSWORD
```

## Required tests

1. Open `terraform output -raw application_url`; confirm the UI loads over HTTPS.
2. Select **Sign in** and authenticate through Cognito Managed Login.
3. Search for `1001`; confirm all five employee fields appear.
4. Search for `1005`; confirm the student's name and IAM user ARN appear.
5. Search for an unknown ID; confirm `Employee not found` appears.
6. Confirm the protected API rejects a request without a token:

```bash
curl -i "$(terraform output -raw application_url)employee/1001"
```

## Export the REST API

```bash
mkdir -p ../docs
aws apigateway get-export \
  --rest-api-id "$(terraform output -raw api_gateway_id)" \
  --stage-name "$(terraform output -raw api_gateway_stage)" \
  --export-type oas30 \
  --parameters '{"extensions":"integrations,authorizers"}' \
  ../docs/api-gateway-openapi.json
```

## Cleanup

After all required screenshots and documentation have been captured:

```bash
terraform destroy
```

## AI assistance

Cursor was used to draft the Terraform, both Lambda functions, the PKCE page,
and this documentation. The implementation process was:

1. I broke the assignment into two routes and the required AWS services, and chose Terraform so the configuration could be reviewed before anything was deployed.
2. I used Cursor to draft the API Gateway REST API: a public `GET /` route for the page and `GET /employee/{id}` for the lookup.
3. I used Cursor to add the Cognito user pool, Managed Login domain, and public app client with the authorization-code grant and no client secret. I checked that the callback URL was the API Gateway address.
4. I reviewed the Cognito authorizer on `GET /employee/{id}` and confirmed that `GET /` remained public. A request without a token returns 401 and does not reach the backend.
5. I used Cursor to draft the page and the PKCE login code. I reviewed where the browser creates the verifier, where Cognito checks it, and where the ID token is sent.
6. I used Cursor to add the DynamoDB table, the student record, and the backend role limited to `dynamodb:GetItem`.
7. I used Cursor to draft the backend Lambda, then checked that it looks up `EmployeeID` and returns all five fields, 404 for an unknown ID, and 400 for an invalid ID.
8. I reviewed both Lambda integrations, then deployed the finished configuration once with `terraform apply` as `hrishi-developer`.
9. I signed in through Cognito and tested the page, employee `1001`, student record `1005`, unknown ID `9999`, and the unauthenticated 401 response.

I selected the architecture, reviewed each component against the assignment, and ran the end-to-end tests.

