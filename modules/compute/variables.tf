variable "region" {
  description = "AWS region this module is deployed in"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool (always in us-east-1)"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool (derived from ARN)"
  type        = string
  default     = ""
}

variable "cognito_client_id" {
  description = "Cognito App Client ID"
  type        = string
  default     = ""
}

variable "sns_topic_arn" {
  description = "Candidate verification SNS topic ARN"
  type        = string
}

variable "your_email" {
  description = "Candidate email for SNS payload"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo URL for SNS payload"
  type        = string
}
