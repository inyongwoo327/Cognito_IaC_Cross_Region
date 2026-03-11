
resource "aws_cognito_user_pool" "main" {
  name = "deployment-user-pool"

  # Require email as username
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = {
    Project = "deployment-region-project"
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "deployment-user-pool-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Enable USER_PASSWORD_AUTH so the test script can authenticate
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  generate_secret = false
}

# Test user — email confirmed immediately via admin API
resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.test_user_email

  attributes = {
    email          = var.test_user_email
    email_verified = "true"
  }

  # Set a permanent password directly
  temporary_password   = var.test_user_password
  message_action       = "SUPPRESS"

  lifecycle {
    ignore_changes = [temporary_password]
  }
}
