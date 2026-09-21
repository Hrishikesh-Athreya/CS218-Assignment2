locals {
  name           = "assignment2"
  stage          = "prod"
  api_url        = "https://${aws_api_gateway_rest_api.app.id}.execute-api.${var.aws_region}.amazonaws.com/${local.stage}"
  cognito_domain = "https://${var.cognito_domain_prefix}.auth.${var.aws_region}.amazoncognito.com"

  employees = {
    "1001" = {
      name         = "Alice Chen"
      salary       = 92000
      date_of_join = "2024-01-15"
      description  = "Cloud Engineering employee"
    }
    "1002" = {
      name         = "Jordan Patel"
      salary       = 88000
      date_of_join = "2023-08-21"
      description  = "Application Development employee"
    }
    "1005" = {
      name         = var.student_name
      salary       = 95000
      date_of_join = "2026-01-15"
      description  = var.student_aws_user_arn
    }
  }
}

data "archive_file" "backend" {
  type        = "zip"
  source_file = "${path.module}/../lambda/backend/handler.py"
  output_path = "${path.module}/backend.zip"
}

data "archive_file" "ui" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/ui"
  output_path = "${path.module}/ui.zip"
}

resource "aws_dynamodb_table" "employees" {
  name         = "${local.name}-employees"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "EmployeeID"

  attribute {
    name = "EmployeeID"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "employees" {
  for_each   = local.employees
  table_name = aws_dynamodb_table.employees.name
  hash_key   = aws_dynamodb_table.employees.hash_key

  item = jsonencode({
    EmployeeID  = { S = each.key }
    Name        = { S = each.value.name }
    Salary      = { N = tostring(each.value.salary) }
    DateOfJoin  = { S = each.value.date_of_join }
    Description = { S = each.value.description }
  })
}

resource "aws_cognito_user_pool" "app" {
  name = "${local.name}-users"
}

resource "aws_cognito_user_pool_domain" "app" {
  domain                = var.cognito_domain_prefix
  user_pool_id          = aws_cognito_user_pool.app.id
  managed_login_version = 2
}

resource "aws_cognito_user_pool_client" "app" {
  name                                 = "${local.name}-web"
  user_pool_id                         = aws_cognito_user_pool.app.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  supported_identity_providers         = ["COGNITO"]
  callback_urls                        = ["${local.api_url}/"]
}

resource "aws_cognito_managed_login_branding" "app" {
  user_pool_id                = aws_cognito_user_pool.app.id
  client_id                   = aws_cognito_user_pool_client.app.id
  use_cognito_provided_values = true
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ui" {
  name               = "${local.name}-ui-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role" "backend" {
  name               = "${local.name}-backend-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "backend" {
  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.employees.arn]
  }
}

resource "aws_iam_role_policy" "backend" {
  name   = "employee-lookup"
  role   = aws_iam_role.backend.id
  policy = data.aws_iam_policy_document.backend.json
}

resource "aws_lambda_function" "ui" {
  function_name    = "${local.name}-ui"
  role             = aws_iam_role.ui.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.ui.output_path
  source_code_hash = data.archive_file.ui.output_base64sha256
  timeout          = 5

  environment {
    variables = {
      API_BASE_URL      = local.api_url
      CALLBACK_URL      = "${local.api_url}/"
      COGNITO_CLIENT_ID = aws_cognito_user_pool_client.app.id
      COGNITO_DOMAIN    = local.cognito_domain
    }
  }
}

resource "aws_lambda_function" "backend" {
  function_name    = "${local.name}-backend"
  role             = aws_iam_role.backend.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.backend.output_path
  source_code_hash = data.archive_file.backend.output_base64sha256
  timeout          = 5

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.employees.name
    }
  }
}

resource "aws_api_gateway_rest_api" "app" {
  name = "${local.name}-hr-lookup"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${local.name}-cognito"
  rest_api_id   = aws_api_gateway_rest_api.app.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.app.arn]
}

resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.app.id
  resource_id   = aws_api_gateway_rest_api.app.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.app.id
  resource_id             = aws_api_gateway_rest_api.app.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ui.invoke_arn
}

resource "aws_api_gateway_resource" "employee" {
  rest_api_id = aws_api_gateway_rest_api.app.id
  parent_id   = aws_api_gateway_rest_api.app.root_resource_id
  path_part   = "employee"
}

resource "aws_api_gateway_resource" "employee_id" {
  rest_api_id = aws_api_gateway_rest_api.app.id
  parent_id   = aws_api_gateway_resource.employee.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "employee" {
  rest_api_id   = aws_api_gateway_rest_api.app.id
  resource_id   = aws_api_gateway_resource.employee_id.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "employee" {
  rest_api_id             = aws_api_gateway_rest_api.app.id
  resource_id             = aws_api_gateway_resource.employee_id.id
  http_method             = aws_api_gateway_method.employee.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend.invoke_arn
}

resource "aws_lambda_permission" "api_ui" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ui.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.app.execution_arn}/*/GET/"
}

resource "aws_lambda_permission" "api_backend" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.app.execution_arn}/*/GET/employee/*"
}

resource "aws_api_gateway_deployment" "app" {
  rest_api_id = aws_api_gateway_rest_api.app.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_authorizer.cognito.id,
      aws_api_gateway_integration.root.id,
      aws_api_gateway_integration.employee.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "app" {
  deployment_id = aws_api_gateway_deployment.app.id
  rest_api_id   = aws_api_gateway_rest_api.app.id
  stage_name    = local.stage
}

