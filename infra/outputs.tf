output "application_url" {
  value = "${local.api_url}/"
}

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.app.id
}

output "api_gateway_stage" {
  value = local.stage
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.app.id
}

output "cognito_managed_login_domain" {
  value = local.cognito_domain
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.app.id
}

