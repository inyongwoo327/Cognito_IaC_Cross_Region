# Secure deployment to AWS multi-region along with CI/CD

## Objective
IaC to provision computer stack in two different regions, secure it using a centralized Cognito pool in us-east-1, write an automated script to test the deployment, and define the CI/CD pipeline to automate the process.

**Name:** Evan Inyong Woo  
**Email:** evanwoo327@gmail.com

---

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| Terraform | 1.6+
| AWS CLI | 2.x
| Python | 3.10+

The AWS credentials need to have permissions for: Cognito, Lambda, API Gateway, DynamoDB, ECS, IAM, CloudWatch Logs, VPC, and SNS (cross-account publish).

---

## Step-by-Step Deployment Guide

### 1. Clone and configure

```bash
git clone https://github.com/inyongwoo327/Cognito_IaC_Cross_Region.git
cd Cognito_IaC_Cross_Region

# Create your variables file from the template
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` for example:

```hcl
test_user_email    = "evanwoo327@gmail.com"      # Own actual email
test_user_password = "Own_Password_With_Cognito_Policy"         # Must meet Cognito policy
github_repo        = "https://github.com/inyongwoo327/Cognito_IaC_Cross_Region.git"
```

`terraform.tfvars` is in `.gitignore` — never commit it.

### 2. Configure AWS credentials

```bash
# Option A — Type AWS Access Keys, region name, and output format 
aws configure

# Option B — environment variables
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

### 3. Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider for both regions.

### 4. Review the plan

```bash
terraform plan
```

### 5. Apply

```bash
terraform apply
```

Type `yes` when prompted.

At the end you will see the outputs.

---

## Running the Test Script

### Create virtual env and install dependencies

```bash
source /Users/User_Name/Cognito_IaC_Cross_Region/.venv/bin/activate
```

```bash
pip3 install boto3 requests
```

### Run

Run the following aws cli command to set the username and password 
and fix Cognito's FORCE_CHANGE_PASSWORD state.

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id "us-east-1_6qnlMD62Z" \
  --username "evanwoo327@gmail.com" \
  --password "P@ssw0rd123" \
  --permanent \
  --region us-east-1
```

Then verify the user status is CONFIRMED.

```bash
aws cognito-idp admin-get-user \
  --user-pool-id "us-east-1_6qnlMD62Z" \
  --username "evanwoo327@gmail.com" \
  --region us-east-1 \
  | grep UserStatus
```

Then run the test script based on the terraform output.

```bash
python test.py \
  --pool-id    "$(terraform output -raw cognito_user_pool_id)" \
  --client-id  "$(terraform output -raw cognito_client_id)" \
  --email      "evanwoo327@gmail.com" \
  --password   "Own_Password_With_Cognito_Policy" \
  --api-us     "$(terraform output -raw api_url_us_east_1)" \
  --api-eu     "$(terraform output -raw api_url_eu_west_1)"
```

## Tear Down Infrastructure

Once you have confirmed the SNS payloads have been sent (both from Lambda via `/greet` and ECS via `/dispatch`), destroy all resources immediately to avoid AWS charges:

```bash
terraform destroy
```

Type `yes` to confirm. All resources in both regions will be deleted.

---

## Multi-Region Provider Design Explanations

The root `main.tf` declares two provider aliases pointing to different regions:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}
```

The `modules/compute` module is instantiated twice — once per alias — via the `providers` meta-argument:

```hcl
module "compute_us" {
  source    = "./modules/compute"
  providers = { aws = aws.us_east_1 }
  ...
}

module "compute_eu" {
  source    = "./modules/compute"
  providers = { aws = aws.eu_west_1 }
  ...
}
```

Inside the module, `data "aws_region" "current" {}` resolves to whichever region the passed-in provider is scoped to. This means the same module code provisions identical infrastructure in both regions with zero duplication.

The Cognito pool is always in `us-east-1`. Both API Gateway JWT authorizers — regardless of their region — reference the pool's ARN and the `https://cognito-idp.us-east-1.amazonaws.com/<pool-id>` issuer URL.

---

## Security Considerations

- **No hardcoded credentials** — all secrets passed via `terraform.tfvars` (gitignored) or GitHub Actions secrets
- **IAM least-privilege** — Lambda roles have explicit, minimal DynamoDB/SNS/ECS permissions only
- **ECS task role** scoped to SNS publish on the single verification topic
- **No NAT Gateway** — Fargate tasks use public subnets with `assignPublicIp: ENABLED`, which can save NAT costs
- **API Gateway JWT auth** — all routes require a valid Cognito token; no unauthenticated access
- **Checkov** scans IaC for misconfigurations in CI before any `apply`
