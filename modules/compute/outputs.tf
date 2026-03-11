output "api_url" {
  description = "API Gateway invoke URL for this region"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.main.arn
}
