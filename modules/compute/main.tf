# Deployed in us-east-1 AND eu-west-1
# Resources include VPC, DynamoDB, Lambda x2, API Gateway, ECS

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  name_prefix = "project-${local.region}"
}

# VPC — public subnets only (no NAT Gateway)

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name_prefix}-public-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name_prefix}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group — ECS Fargate outbound only

resource "aws_security_group" "ecs_task" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Allow ECS Fargate egress to internet (SNS publish)"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-ecs-sg" }
}

# DynamoDB — Logs for greeting

resource "aws_dynamodb_table" "greeting_logs" {
  name         = "GreetingLogs-${local.region}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = { Project = "deployment-region-project" }
}

# IAM — Lambda execution role

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_perms" {
  # DynamoDB — regional table only
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.greeting_logs.arn]
  }

  # SNS publish to live topic in us-east-1
  statement {
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }

  # ECS RunTask (for dispatcher Lambda)
  statement {
    actions   = ["ecs:RunTask", "iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_perms" {
  name   = "${local.name_prefix}-lambda-perms"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_perms.json
}

# Lambda — Greeter

data "archive_file" "greeter" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/greeter/index.py"
  output_path = "${path.module}/../../lambda/greeter/greeter.zip"
}

resource "aws_lambda_function" "greeter" {
  function_name    = "${local.name_prefix}-greeter"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.greeter.output_path
  source_code_hash = data.archive_file.greeter.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE  = aws_dynamodb_table.greeting_logs.name
      SNS_TOPIC_ARN   = var.sns_topic_arn
      YOUR_EMAIL      = var.your_email
      GITHUB_REPO     = var.github_repo
      EXECUTING_REGION = local.region
    }
  }
}

resource "aws_lambda_permission" "greeter_apigw" {
  statement_id  = "AllowAPIGatewayGreeter"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Lambda — Dispatcher

data "archive_file" "dispatcher" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/dispatcher/index.py"
  output_path = "${path.module}/../../lambda/dispatcher/dispatcher.zip"
}

resource "aws_lambda_function" "dispatcher" {
  function_name    = "${local.name_prefix}-dispatcher"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.dispatcher.output_path
  source_code_hash = data.archive_file.dispatcher.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      ECS_CLUSTER_ARN       = aws_ecs_cluster.main.arn
      ECS_TASK_DEF_ARN      = aws_ecs_task_definition.sns_publisher.arn
      ECS_SUBNET_ID         = aws_subnet.public[0].id
      ECS_SECURITY_GROUP_ID = aws_security_group.ecs_task.id
      EXECUTING_REGION      = local.region
    }
  }
}

resource "aws_lambda_permission" "dispatcher_apigw" {
  statement_id  = "AllowAPIGatewayDispatcher"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatcher.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
