# Root main.tf orchestrates: Auth (us-east-1) and Compute in 2 regions (us-east-1 and eu-west-1).

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

# Auth module (us-east-1 only)
module "auth" {
  source = "./modules/auth"

  providers = {
    aws = aws.us_east_1
  }

  test_user_email = var.test_user_email
  test_user_password = var.test_user_password
}

# Compute: us-east-1
module "compute_us" {
  source = "./modules/compute"

  providers = {
    aws = aws.us_east_1
  }

  region                = "us-east-1"
  cognito_user_pool_arn = module.auth.user_pool_arn
  cognito_client_id     = module.auth.client_id
  sns_topic_arn         = var.sns_topic_arn
  your_email            = var.test_user_email
  github_repo           = var.github_repo
}

# Compute: eu-west-1
module "compute_eu" {
  source = "./modules/compute"

  providers = {
    aws = aws.eu_west_1
  }

  region                = "eu-west-1"
  cognito_user_pool_arn = module.auth.user_pool_arn
  cognito_client_id     = module.auth.client_id
  sns_topic_arn         = var.sns_topic_arn
  your_email            = var.test_user_email
  github_repo           = var.github_repo
}
