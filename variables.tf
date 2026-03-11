variable "test_user_email" {
  type = string
}

variable "test_user_password" {
  type      = string
  sensitive = true
}

variable "sns_topic_arn" {
  description = "Candidate verification SNS topic ARN"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo URL for SNS payload"
  type        = string
}
