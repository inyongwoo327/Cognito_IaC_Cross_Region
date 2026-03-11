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
| pip packages

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

Edit `terraform.tfvars`:

```hcl
test_user_email    = "evanwoo327@gmail.com"      # YOUR actual email
test_user_password = "Please_Meet_Cognito_Policy"         # Must meet Cognito policy
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

### Install dependencies

```bash
pip install boto3 requests
```

### Run

```bash
python test.py \
  --pool-id    "$(terraform output -raw cognito_user_pool_id)" \
  --client-id  "$(terraform output -raw cognito_client_id)" \
  --email      "evanwoo327@gmail.com" \
  --password   "Please_Meet_Cognito_Policy" \
  --api-us     "$(terraform output -raw api_url_us_east_1)" \
  --api-eu     "$(terraform output -raw api_url_eu_west_1)"
```

## Tear Down Infrastructure

Once you have confirmed the SNS payloads have been sent (both from Lambda via `/greet` and ECS via `/dispatch`), destroy all resources immediately to avoid AWS charges:

```bash
terraform destroy
```

Type `yes` to confirm. All resources in both regions will be deleted.