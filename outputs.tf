# outputs after 'terraform apply'

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID (us-east-1)"
  value       = module.auth.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN (us-east-1)"
  value       = module.auth.user_pool_arn
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = module.auth.client_id
}

output "api_url_us_east_1" {
  description = "API Gateway invoke URL — us-east-1"
  value       = module.compute_us.api_url
}

output "api_url_eu_west_1" {
  description = "API Gateway invoke URL — eu-west-1"
  value       = module.compute_eu.api_url
}
