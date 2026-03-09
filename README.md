# Infrastructure-as-Code Multi-Environment Landing Zone

A production-grade, reusable Terraform module library that provisions secure networking foundations across **Azure** and **AWS** — with remote state management in Azure Storage and CI/CD pipelines using **Azure DevOps** and **AWS CodePipeline**.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        AZURE (Primary)                           │
│                                                                  │
│  ┌─────────────┐     VNet Peering      ┌──────────────────────┐  │
│  │  Hub VNet    │◄────────────────────►│  Spoke VNet          │  │
│  │  10.x.0.0/16│                       │  (Workload)          │  │
│  │             │                       │                      │  │
│  │ ┌─────────┐ │                       │ ┌──────┐ ┌────────┐ │  │
│  │ │Gateway  │ │                       │ │App   │ │Data    │ │  │
│  │ │Subnet   │ │                       │ │Subnet│ │Subnet  │ │  │
│  │ ├─────────┤ │                       │ ├──────┤ ├────────┤ │  │
│  │ │Firewall │ │                       │ │AppGW │ │        │ │  │
│  │ │Subnet   │ │                       │ │Subnet│ │        │ │  │
│  │ ├─────────┤ │                       │ └──────┘ └────────┘ │  │
│  │ │Bastion  │ │                       └──────────────────────┘  │
│  │ │Subnet   │ │                              ▲                  │
│  │ ├─────────┤ │                              │ NSG              │
│  │ │Shared   │ │                              │ Rules            │
│  │ │Services │ │                              ▼                  │
│  │ └─────────┘ │                       ┌──────────────────────┐  │
│  └─────────────┘                       │  Application Gateway │  │
│                                        └──────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       AWS (Secondary)                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │  VPC (10.x.0.0/16)                                     │     │
│  │                                                         │     │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │     │
│  │  │ Public Sub  │  │ Public Sub  │  │ Public Sub  │     │     │
│  │  │ AZ-a        │  │ AZ-b        │  │ AZ-c        │     │     │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │     │
│  │         │ IGW            │                │             │     │
│  │  ┌──────┴──────┐  ┌─────┴───────┐  ┌─────┴───────┐     │     │
│  │  │ Private Sub │  │ Private Sub │  │ Private Sub │     │     │
│  │  │ AZ-a        │  │ AZ-b        │  │ AZ-c        │     │     │
│  │  └──────┬──────┘  └─────────────┘  └─────────────┘     │     │
│  │         │ NAT                                           │     │
│  │  ┌──────┴──────┐  ┌──────────┐  ┌──────────────────┐   │     │
│  │  │ NAT Gateway │  │ Bastion  │  │ S3 (Artifacts +  │   │     │
│  │  └─────────────┘  │ (EC2)    │  │    Flow Logs)    │   │     │
│  │                    └──────────┘  └──────────────────┘   │     │
│  └─────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
iac-landing-zone/
├── bootstrap/                    # One-time setup: Azure Storage for remote state
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── modules/
│   ├── azure/
│   │   ├── hub-vnet/             # Hub virtual network (gateway, firewall, bastion)
│   │   ├── spoke-vnet/           # Spoke VNet with peering to hub
│   │   ├── nsg/                  # Network Security Groups with rules
│   │   └── app-gateway/          # Application Gateway v2
│   └── aws/
│       ├── vpc/                  # VPC with public/private subnets, NAT, IGW
│       ├── ec2/                  # EC2 instances with security groups
│       ├── s3/                   # S3 buckets with encryption + lifecycle
│       └── codepipeline/         # AWS CodePipeline + CodeBuild for CI/CD
├── environments/
│   ├── dev/                      # Development environment
│   ├── staging/                  # Staging environment (+ App Gateway)
│   └── prod/                     # Production (WAF, flow logs, bastion)
├── pipelines/
│   └── azure-devops/             # Azure DevOps CI/CD pipelines
│       ├── ci-pipeline.yml       # Plan on PR
│       ├── cd-pipeline.yml       # Apply on merge
│       └── templates/            # Reusable pipeline templates
├── .gitignore
├── .editorconfig
├── README.md
└── READMEEXPLAINED.md
```

## Environments

| Environment | Azure CIDR | AWS CIDR | NAT Gateway | App Gateway | Flow Logs | Bastion |
|-------------|-----------|----------|-------------|-------------|-----------|---------|
| **dev** | 10.0.0.0/16 (hub) + 10.1.0.0/16 (spoke) | 10.10.0.0/16 | No | No | No | No |
| **staging** | 10.20.0.0/16 (hub) + 10.21.0.0/16 (spoke) | 10.30.0.0/16 | Yes | Standard_v2 | No | No |
| **prod** | 10.40.0.0/16 (hub) + 10.41.0.0/16 (spoke) | 10.50.0.0/16 | Yes | WAF_v2 | Yes | Yes |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (`az login`)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) (`aws configure`)
- Azure subscription + AWS account
- Azure DevOps organization (for Azure CI/CD)
- AWS CodeStar Connection (for AWS CI/CD)

## Quick Start

### 1. Bootstrap Remote State

```bash
cd bootstrap
terraform init
terraform apply -var="storage_account_name=stterraformstate$(openssl rand -hex 4)"
```

### 2. Deploy an Environment

```bash
cd environments/dev

# Update terraform.tfvars with your subscription/account IDs
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Set Up Azure DevOps Pipeline

1. Create a Variable Group named `terraform-credentials` with:
   - `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`
   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`
   - `TF_STATE_RG`, `TF_STATE_SA`
2. Import `pipelines/azure-devops/ci-pipeline.yml` as a Build Pipeline
3. Import `pipelines/azure-devops/cd-pipeline.yml` as a Release Pipeline
4. Create an Environment named `production` with approval gates

### 4. Set Up AWS CodePipeline

The `modules/aws/codepipeline` module creates the full pipeline as Terraform code. Add it to your environment config:

```hcl
module "aws_pipeline" {
  source = "../../modules/aws/codepipeline"

  environment            = "dev"
  repository_id          = "JaithraSarma/iac-landing-zone"
  codestar_connection_arn = "arn:aws:codestar-connections:..."
  approval_email         = "team@example.com"
}
```

## CI/CD Flow

### Azure DevOps (Azure Infrastructure)

```
PR Created → CI Pipeline → terraform validate → terraform plan (artifact)
                                                          ↓
PR Merged  → CD Pipeline → Apply Dev → Apply Staging → [Approval] → Apply Prod
```

### AWS CodePipeline (AWS Infrastructure)

```
Push to main → Source → CodeBuild (Plan) → Manual Approval → CodeBuild (Apply)
```

## Security Features

- **NSG rules**: Defense-in-depth with deny-all default + explicit allow rules
- **WAF**: Web Application Firewall on production App Gateway
- **Encryption**: S3 server-side encryption (AES-256) on all buckets
- **IMDSv2**: EC2 instances require token-based metadata access
- **Public access blocked**: All S3 buckets block public access
- **Private subnets**: Workload resources isolated from direct internet access
- **VPC flow logs**: Production captures all traffic for audit trail

## License

MIT
