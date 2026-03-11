variable "test_user_email" {
  type = string
}

variable "test_user_password" {
  type      = string
  sensitive = true
}
