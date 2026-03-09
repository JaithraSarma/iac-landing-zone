# READMEEXPLAINED.md — Full Project Deep-Dive (Interview-Ready)

This document explains **every aspect** of the Infrastructure-as-Code Multi-Environment Landing Zone project from start to finish. It covers architecture decisions, every file's purpose, how Terraform works under the hood, networking fundamentals, CI/CD design, security posture, and the kind of questions a recruiter or interviewer might ask.

---

## Table of Contents

1. [What This Project Is](#1-what-this-project-is)
2. [Why It Exists](#2-why-it-exists)
3. [Core Concepts You Must Understand](#3-core-concepts-you-must-understand)
4. [Project Structure Explained](#4-project-structure-explained)
5. [Azure Architecture Deep-Dive](#5-azure-architecture-deep-dive)
6. [AWS Architecture Deep-Dive](#6-aws-architecture-deep-dive)
7. [Terraform Mechanics](#7-terraform-mechanics)
8. [Remote State Management](#8-remote-state-management)
9. [Module Design Philosophy](#9-module-design-philosophy)
10. [Environment Promotion Strategy](#10-environment-promotion-strategy)
11. [CI/CD Pipeline Design](#11-cicd-pipeline-design)
12. [Security Design](#12-security-design)
13. [Networking Fundamentals](#13-networking-fundamentals)
14. [Cost Optimization](#14-cost-optimization)
15. [Common Interview Questions & Answers](#15-common-interview-questions--answers)
16. [Troubleshooting Guide](#16-troubleshooting-guide)
17. [What I Would Add Next](#17-what-i-would-add-next)

---

## 1. What This Project Is

This is a **reusable Terraform module library** that provisions a secure networking foundation across two clouds:

- **Azure (primary)**: Hub-spoke virtual network topology with Network Security Groups and Application Gateway
- **AWS (secondary)**: VPC with public/private subnets, NAT Gateway, Internet Gateway, EC2 bastion, and S3 buckets

The infrastructure is deployed across **three environments** (dev, staging, prod), each with progressively more features and tighter security. State is stored remotely in Azure Blob Storage. CI/CD uses **Azure DevOps** for Azure-side infrastructure and **AWS CodePipeline + CodeBuild** for AWS-side infrastructure — both native to their respective clouds.

### What This Project Demonstrates

| Skill | How It's Demonstrated |
|-------|----------------------|
| IaC Fundamentals | Terraform HCL, providers, resources, data sources |
| Modular Design | Reusable modules with inputs/outputs, no hardcoded values |
| Multi-Cloud | Azure + AWS in the same codebase, separate providers |
| Networking | Hub-spoke (Azure), VPC with subnets (AWS), peering, NSGs |
| State Management | Remote backend in Azure Storage with per-environment state files |
| CI/CD | Azure DevOps pipelines (plan on PR, apply on merge) + AWS CodePipeline |
| Security | NSGs, WAF, encryption, IMDSv2, public access blocks, deny-by-default |
| Environment Strategy | Dev/staging/prod with feature flags and progressive hardening |

---

## 2. Why It Exists

Most companies don't live in a single cloud. A DevOps engineer who can write modular Terraform across Azure and AWS, manage state properly, and set up pipelines that won't accidentally destroy production — that person is valuable.

This project proves:
- **You won't be dangerous with a Terraform file.** You understand blast radius (what happens if you run `terraform destroy`), modularity (changes to one module don't cascade), and state isolation (dev can't accidentally overwrite prod state).
- **You understand infrastructure.** You're not clicking buttons in the Azure portal. You can reason about CIDR blocks, subnet segmentation, peering, route tables, and security groups.
- **You understand the deployment lifecycle.** Plan on PR → review → approve → apply. Not YOLO `terraform apply` on your laptop.

---

## 3. Core Concepts You Must Understand

### 3.1 Infrastructure as Code (IaC)

IaC means defining your infrastructure in **declarative configuration files** instead of manually creating resources through a portal or CLI. Benefits:
- **Reproducibility**: Run the same code, get the same infrastructure
- **Version control**: Git history tracks every change
- **Code review**: Infrastructure changes go through PRs, just like application code
- **Blast radius control**: `terraform plan` shows you exactly what will change before you apply

### 3.2 Terraform Basics

Terraform uses **HashiCorp Configuration Language (HCL)**. Key concepts:

- **Provider**: Plugin that talks to a cloud API (e.g., `azurerm`, `aws`)
- **Resource**: A single infrastructure object (e.g., `aws_vpc`, `azurerm_virtual_network`)
- **Data Source**: Read-only query to fetch info about existing resources
- **Module**: A reusable package of Terraform configuration (a directory with `.tf` files)
- **State**: A JSON file that maps your config to real cloud resources
- **Plan**: A diff showing what Terraform will create/update/destroy
- **Apply**: Execute the plan to make changes

### 3.3 Hub-Spoke Topology (Azure)

The hub-spoke model is Microsoft's recommended architecture for enterprise networking:

- **Hub VNet**: Central network containing shared services (VPN gateway, firewall, bastion, DNS). All traffic between spokes passes through the hub.
- **Spoke VNets**: Workload-specific networks peered to the hub. Each spoke is isolated from other spokes unless explicitly routed through the hub.

Why hub-spoke?
- **Centralized security**: Firewall and gateway in one place
- **Cost sharing**: One VPN gateway shared across all spokes
- **Isolation**: Workloads in different spokes can't talk to each other by default
- **Scalability**: Add new spokes without touching the hub

### 3.4 VPC Architecture (AWS)

AWS VPC (Virtual Private Cloud) is the fundamental networking construct:

- **Public subnets**: Have a route to the Internet Gateway → resources get public IPs
- **Private subnets**: No direct internet access → use NAT Gateway for outbound
- **Internet Gateway (IGW)**: Allows public subnets to reach the internet
- **NAT Gateway**: Allows private subnets to reach the internet for updates/patches without being publicly accessible
- **Route Tables**: Rules that determine where network traffic goes

---

## 4. Project Structure Explained

### 4.1 `bootstrap/` — One-Time State Storage Setup

```
bootstrap/
├── main.tf          # Creates Azure Storage Account + container
├── variables.tf     # Storage account name, location, RG name
└── outputs.tf       # Exports storage account details
```

**Why**: Terraform needs somewhere to store its state file. We use Azure Blob Storage with:
- **GRS replication**: State is replicated to a secondary Azure region
- **Versioning**: Every state change is versioned (rollback protection)
- **TLS 1.2**: Encrypted in transit
- **30-day retention**: Deleted blobs are recoverable for 30 days

**Chicken-and-egg problem**: This bootstrap itself uses local state (since the remote backend doesn't exist yet). You run this once, then all other environments use the created storage account.

### 4.2 `modules/` — Reusable Building Blocks

Each module follows the Terraform standard structure:
- `main.tf` — Resources
- `variables.tf` — Inputs (what the caller configures)
- `outputs.tf` — Outputs (what the module exports for other modules to use)

#### Azure Modules

| Module | Purpose | Key Resources |
|--------|---------|---------------|
| `hub-vnet` | Central hub network | Resource Group, VNet, GatewaySubnet, AzureFirewallSubnet, AzureBastionSubnet, Shared Services Subnet |
| `spoke-vnet` | Workload network + peering | Resource Group, VNet, dynamic subnets, bidirectional VNet peering |
| `nsg` | Network security rules | NSG, security rules, subnet associations |
| `app-gateway` | Layer 7 load balancer/WAF | Public IP, Application Gateway v2 with dynamic backend pools, listeners, routing rules |

#### AWS Modules

| Module | Purpose | Key Resources |
|--------|---------|---------------|
| `vpc` | Full VPC with subnets | VPC, public/private subnets across AZs, IGW, NAT Gateway, route tables, flow logs |
| `ec2` | Compute instances | EC2 instance, security group, encrypted root volume, IMDSv2 |
| `s3` | Object storage | S3 bucket with versioning, AES-256 encryption, public access block, lifecycle rules |
| `codepipeline` | Native AWS CI/CD | CodePipeline, CodeBuild (plan + apply), S3 artifact bucket, IAM roles, SNS approval topic |

### 4.3 `environments/` — Per-Environment Configurations

Each environment directory (`dev/`, `staging/`, `prod/`) is a **root module** — it calls the reusable modules with environment-specific values.

```
environments/dev/
├── main.tf           # Module calls with dev-specific parameters
├── variables.tf      # Input variable declarations
├── locals.tf         # Common tags
├── outputs.tf        # Exported values
└── terraform.tfvars  # Actual values (subscription IDs, regions)
```

**Key difference between environments:**
- **Dev**: Minimal — no NAT gateway (saves $32/month), no App Gateway, no flow logs
- **Staging**: Medium — NAT gateway enabled, Standard_v2 App Gateway, 2 AZs
- **Prod**: Full — WAF_v2 App Gateway, VPC flow logs, EC2 bastion, 3 AZs, tightest NSG rules

### 4.4 `pipelines/` — CI/CD Definitions

#### Azure DevOps (`pipelines/azure-devops/`)

| File | Purpose |
|------|---------|
| `ci-pipeline.yml` | Triggered on PR → validates all modules → plans each environment |
| `cd-pipeline.yml` | Triggered on merge to main → applies dev → staging → prod (with approval) |
| `templates/install-terraform.yml` | Reusable step: installs Terraform |
| `templates/terraform-plan.yml` | Reusable job: init + validate + plan + publish artifact |
| `templates/terraform-apply.yml` | Reusable job: init + apply (from saved plan or fresh) |

#### AWS CodePipeline (`modules/aws/codepipeline/`)

This is a **Terraform module** (not a YAML file) because AWS CodePipeline is provisioned as infrastructure. It creates:
- CodePipeline with 4 stages: Source → Plan → Approve → Apply
- CodeBuild projects for plan and apply
- S3 artifact bucket
- IAM roles with least-privilege policies
- SNS topic for approval notifications

---

## 5. Azure Architecture Deep-Dive

### 5.1 Hub VNet

The hub is the central networking point. It contains subnets with **reserved names** that Azure services require:

- **GatewaySubnet** (`10.x.1.0/24`): Required name for VPN Gateway or ExpressRoute Gateway. This connects your Azure network to on-premises or other clouds.
- **AzureFirewallSubnet** (`10.x.2.0/24`): Required name for Azure Firewall. All traffic between spokes can be routed through here for inspection.
- **AzureBastionSubnet** (`10.x.3.0/24`): Required name for Azure Bastion. Provides secure RDP/SSH access to VMs without public IPs.
- **Shared Services** (`10.x.4.0/24`): Custom subnet for DNS servers, domain controllers, monitoring agents, etc.

### 5.2 Spoke VNet

Each spoke represents a workload (e.g., a microservice, a team's resources). The spoke module:

1. Creates a VNet with dynamic subnets (using `for_each`)
2. Creates **bidirectional VNet peering** with the hub:
   - Spoke → Hub: `allow_forwarded_traffic = true` (spoke can reach other spokes via hub firewall)
   - Hub → Spoke: `allow_gateway_transit = true` (hub's VPN gateway can serve the spoke)

**Subnet delegations**: The subnet config supports optional delegations for Azure PaaS services (e.g., delegating a subnet to Azure App Service or Azure Container Instances).

### 5.3 NSG (Network Security Groups)

NSGs are stateful firewalls attached to subnets (or NICs). Our design:

- **Deny-all default**: Priority 4096 rule denies all inbound traffic
- **Explicit allows**: Lower priority numbers (100, 110, 120) allow specific traffic
- **Least privilege**: Data subnet only allows SQL (port 1433) from the app subnet

Example rule chain for the app subnet:
```
Priority 100: Allow HTTPS (443) from hub CIDR → ALLOW
Priority 110: Allow HTTP (80) from hub CIDR → ALLOW
Priority 4096: Deny all inbound → DENY
```

### 5.4 Application Gateway

Azure Application Gateway is a Layer 7 (HTTP/HTTPS) load balancer. In this project:

- **Staging**: Uses `Standard_v2` SKU — basic load balancing
- **Production**: Uses `WAF_v2` SKU — includes Web Application Firewall for OWASP protection

Components:
- **Frontend IP**: Public IP for incoming traffic
- **Listeners**: Listen on port 80 (HTTP)
- **Backend Pools**: Target VMs/services
- **HTTP Settings**: Health probes, timeouts, cookie affinity
- **Routing Rules**: Map listener → backend pool

---

## 6. AWS Architecture Deep-Dive

### 6.1 VPC Design

The VPC module creates a multi-AZ network:

```
VPC (10.x.0.0/16)
├── Public Subnets (one per AZ)
│   ├── 10.x.0.0/24 (AZ-a) → Route: 0.0.0.0/0 → IGW
│   ├── 10.x.1.0/24 (AZ-b) → Route: 0.0.0.0/0 → IGW
│   └── 10.x.2.0/24 (AZ-c) → Route: 0.0.0.0/0 → IGW   [prod only]
├── Private Subnets (one per AZ)
│   ├── 10.x.3.0/24 (AZ-a) → Route: 0.0.0.0/0 → NAT
│   ├── 10.x.4.0/24 (AZ-b) → Route: 0.0.0.0/0 → NAT
│   └── 10.x.5.0/24 (AZ-c) → Route: 0.0.0.0/0 → NAT   [prod only]
├── Internet Gateway
├── NAT Gateway (in first public subnet)
└── Route Tables (public + private)
```

**Why multiple AZs?** Availability Zones are physically separate data centers within a region. Spreading subnets across AZs means if one data center goes down, your app stays up.

The `cidrsubnet()` function automatically calculates subnet CIDRs:
```hcl
cidrsubnet("10.10.0.0/16", 8, 0) = "10.10.0.0/24"  # Public AZ-a
cidrsubnet("10.10.0.0/16", 8, 1) = "10.10.1.0/24"  # Public AZ-b
cidrsubnet("10.10.0.0/16", 8, 2) = "10.10.2.0/24"  # Private AZ-a
cidrsubnet("10.10.0.0/16", 8, 3) = "10.10.3.0/24"  # Private AZ-b
```

### 6.2 NAT Gateway

NAT (Network Address Translation) Gateway allows private subnet resources to reach the internet (e.g., for OS updates, pulling Docker images) without being directly reachable from the internet.

- **Dev**: NAT Gateway disabled to save ~$32/month
- **Staging/Prod**: NAT Gateway enabled

The NAT Gateway lives in a public subnet (it needs internet access) and private subnets route through it.

### 6.3 EC2 Bastion Host (Production Only)

A bastion host is a hardened jump server. Instead of giving every EC2 instance a public IP and SSH access, you:

1. SSH into the bastion (in a public subnet)
2. From the bastion, SSH into private instances

Security hardening:
- **IMDSv2 required**: `http_tokens = "required"` prevents SSRF attacks against the metadata service
- **Encrypted root volume**: `encrypted = true` on the root EBS volume
- **Restricted ingress**: Only `bastion_allowed_cidrs` can SSH in

### 6.4 S3 Buckets

Every S3 bucket follows security best practices:
- **Versioning**: Enabled — accidental overwrites are recoverable
- **AES-256 encryption**: Server-side encryption enabled by default
- **Public access blocked**: All four public access block settings are `true`
- **Lifecycle rules**: Objects transition to cheaper storage tiers and eventually expire

---

## 7. Terraform Mechanics

### 7.1 How `terraform init` Works

When you run `terraform init`:
1. Downloads provider plugins (azurerm, aws) into `.terraform/providers/`
2. Downloads module source code (if using remote modules)
3. Initializes the backend (connects to Azure Storage for remote state)
4. Creates `.terraform.lock.hcl` (locks provider versions)

### 7.2 How `terraform plan` Works

The plan phase:
1. Reads the current state from the backend
2. Reads your `.tf` configuration files
3. Queries the cloud API to get the actual state of resources
4. Computes a diff: what needs to be created, updated, or destroyed
5. Outputs the diff for review

This is the **blast radius check** — you see exactly what will change before anything happens.

### 7.3 How `terraform apply` Works

1. Executes the plan (or generates a new one)
2. Creates/updates/destroys resources in dependency order
3. Updates the state file with the new resource IDs and attributes
4. Outputs any defined output values

### 7.4 State File

The state file (`terraform.tfstate`) is **critical**:
- It maps your HCL resources to real cloud resource IDs
- Without it, Terraform doesn't know what it previously created
- **Never edit it manually**
- **Never commit it to git** (contains sensitive data like access keys)
- **Always use remote state** in a team setting

### 7.5 Provider Configuration

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "aws" {
  region = var.aws_region
}
```

Both providers can be configured in the same root module. Terraform handles authentication via:
- **Azure**: `az login` (interactive) or `ARM_CLIENT_ID`/`ARM_CLIENT_SECRET` env vars (service principal)
- **AWS**: `aws configure` (interactive) or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` env vars

---

## 8. Remote State Management

### 8.1 Why Remote State?

Local state (`terraform.tfstate` on disk) breaks in teams:
- **Concurrency**: Two people running `terraform apply` simultaneously corrupt the state
- **Sharing**: Everyone needs access to the same state file
- **Security**: State contains secrets — it shouldn't live on laptops

### 8.2 Azure Storage Backend

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "stterraformstate001"
  container_name       = "tfstate"
  key                  = "dev/terraform.tfstate"
}
```

Features:
- **State locking**: Azure Blob Storage supports leases — only one operation at a time
- **Versioning**: Every state change creates a new blob version
- **Encryption**: Encrypted at rest and in transit (TLS 1.2)
- **GRS replication**: State is replicated to a paired Azure region

### 8.3 Per-Environment State Isolation

Each environment gets its own state file key:
- `dev/terraform.tfstate`
- `staging/terraform.tfstate`
- `prod/terraform.tfstate`

This means `terraform destroy` in dev **cannot** affect prod. The state files are completely independent.

---

## 9. Module Design Philosophy

### 9.1 What Makes a Good Module?

1. **Single responsibility**: Each module does one thing (e.g., create a VNet, not "create all Azure networking")
2. **No hardcoded values**: Everything is a variable with sensible defaults
3. **Clear interfaces**: `variables.tf` defines inputs, `outputs.tf` defines outputs
4. **Composable**: Modules can reference each other's outputs

### 9.2 Example: How Modules Connect

```hcl
# Hub module creates a VNet and exports its ID
module "azure_hub" {
  source    = "../../modules/azure/hub-vnet"
  vnet_name = "vnet-hub-dev"
  ...
}

# Spoke module takes the hub's ID as input for peering
module "azure_spoke" {
  source      = "../../modules/azure/spoke-vnet"
  hub_vnet_id = module.azure_hub.vnet_id  # ← output from hub
  ...
}

# NSG module takes the spoke's subnet ID for association
module "nsg" {
  source     = "../../modules/azure/nsg"
  subnet_ids = [module.azure_spoke.subnet_ids["snet-app"]]  # ← output from spoke
  ...
}
```

### 9.3 Dynamic Blocks

The spoke module uses `for_each` for subnets:
```hcl
variable "subnets" {
  type = map(object({
    address_prefix = string
    delegation     = optional(object({...}))
  }))
}

resource "azurerm_subnet" "workload" {
  for_each         = var.subnets
  name             = each.key
  address_prefixes = [each.value.address_prefix]
}
```

This means you can add/remove subnets just by changing the variable — no code changes needed.

---

## 10. Environment Promotion Strategy

### 10.1 Progressive Feature Enablement

The project uses **feature flags** via Terraform variables:

```hcl
# Dev: NAT disabled (cost savings)
enable_nat_gateway = false  # var.environment != "dev"

# Prod: WAF enabled
sku_name = "WAF_v2"  # vs "Standard_v2" in staging

# Prod: Flow logs enabled
enable_flow_logs = true
```

### 10.2 CIDR Planning

Each environment uses non-overlapping CIDR ranges:

| Environment | Hub VNet | Spoke VNet | AWS VPC |
|-------------|---------|------------|---------|
| dev | 10.0.0.0/16 | 10.1.0.0/16 | 10.10.0.0/16 |
| staging | 10.20.0.0/16 | 10.21.0.0/16 | 10.30.0.0/16 |
| prod | 10.40.0.0/16 | 10.41.0.0/16 | 10.50.0.0/16 |

Why non-overlapping? If you ever need to peer environments (e.g., staging talking to a shared prod service), overlapping CIDRs would break routing.

---

## 11. CI/CD Pipeline Design

### 11.1 Azure DevOps Pipelines

**Why Azure DevOps for Azure infrastructure?**
- Native integration with Azure Resource Manager
- Built-in Terraform task (`TerraformInstaller@1`)
- Environments with approval gates for production
- Variable Groups for secure credential storage

#### CI Pipeline (Plan on PR)

```
PR to main
  └── Stage: Validate
  │     └── terraform init -backend=false + terraform validate (all modules)
  ├── Stage: Plan Dev
  │     └── terraform init → validate → plan → publish artifact
  ├── Stage: Plan Staging
  │     └── terraform init → validate → plan → publish artifact
  └── Stage: Plan Prod
        └── terraform init → validate → plan → publish artifact
```

The plan output is saved as a pipeline artifact (`tfplan`) so the exact same plan can be applied later — no drift between plan and apply.

#### CD Pipeline (Apply on Merge)

```
Merge to main
  └── Stage: Apply Dev
  │     └── download plan artifact → terraform apply
  ├── Stage: Apply Staging (depends on Dev)
  │     └── download plan artifact → terraform apply
  └── Stage: Apply Prod (depends on Staging)
        └── deployment job with Environment "production" (manual approval gate)
        └── terraform apply
```

**Why the deployment job for prod?** Azure DevOps Environments support **approval gates** — a human must click "Approve" before the prod apply runs. This prevents accidental production changes.

#### Templates

Templates are reusable YAML snippets:
- `install-terraform.yml`: Installs a specific Terraform version
- `terraform-plan.yml`: Full plan job (init → validate → plan → artifact)
- `terraform-apply.yml`: Full apply job (init → apply → output)

### 11.2 AWS CodePipeline

**Why AWS CodePipeline for AWS infrastructure?**
- Native AWS service — no external CI/CD tool needed
- Integrates with CodeBuild, S3, SNS, IAM
- CodeStar Connections for GitHub source integration
- The pipeline itself is defined as Terraform code (infrastructure all the way down)

Pipeline stages:
1. **Source**: Pulls code from GitHub via CodeStar Connection
2. **Plan**: CodeBuild project runs `terraform init + validate + plan`
3. **Approve**: Manual approval via SNS email notification
4. **Apply**: CodeBuild project runs `terraform apply` using the saved plan

#### Why Terraform for the Pipeline?

The `modules/aws/codepipeline` module provisions the pipeline as infrastructure. This means:
- The pipeline is version-controlled
- It can be replicated per environment
- IAM policies are explicit and auditable
- No manual ClickOps in the AWS console

---

## 12. Security Design

### 12.1 Network Security (Defense in Depth)

```
Layer 1: VNet/VPC Isolation       → Separate address spaces per environment
Layer 2: Subnet Segmentation      → App, data, gateway, firewall in separate subnets
Layer 3: NSG / Security Groups    → Deny-all default, explicit allow rules
Layer 4: Application Gateway/WAF  → OWASP protection on HTTP traffic (prod)
Layer 5: Encryption               → TLS in transit, AES-256 at rest
```

### 12.2 Principle of Least Privilege

- **NSG rules**: Data subnet only accepts SQL traffic from the app subnet — not from the entire VNet
- **IAM policies**: CodeBuild role only has permissions it needs (not `*` on everything — though simplified in this demo)
- **S3 public access**: All four blocks enabled — even if someone misconfigures a bucket policy, public access is still denied
- **IMDSv2**: Prevents SSRF exploitation of EC2 metadata (the capital-C CVE that leaked Capital One data)

### 12.3 Secrets Management

- **State file**: Stored in encrypted Azure Blob Storage, never committed to git
- **Credentials**: Stored in Azure DevOps Variable Groups (encrypted at rest) and AWS CodeBuild environment variables
- **`.gitignore`**: Excludes `*.auto.tfvars`, `secret.tfvars`, `.terraform/`, `*.tfstate`

---

## 13. Networking Fundamentals

### 13.1 CIDR Notation

CIDR (Classless Inter-Domain Routing) defines IP ranges:
- `10.0.0.0/16` = 65,536 IPs (10.0.0.0 to 10.0.255.255)
- `10.0.1.0/24` = 256 IPs (10.0.1.0 to 10.0.1.255)
- Smaller suffix = more IPs

### 13.2 Subnetting

We split a /16 VNet into /24 subnets:
```
10.0.0.0/16 (hub VNet = 65,536 IPs)
├── 10.0.1.0/24 (GatewaySubnet = 256 IPs)
├── 10.0.2.0/24 (FirewallSubnet = 256 IPs)
├── 10.0.3.0/24 (BastionSubnet = 256 IPs)
└── 10.0.4.0/24 (SharedServices = 256 IPs)
```

Azure reserves 5 IPs per subnet (network, gateway, 2x DNS, broadcast), so a /24 gives you 251 usable IPs.

### 13.3 VNet Peering vs. VPN Gateway

| Feature | VNet Peering | VPN Gateway |
|---------|-------------|-------------|
| Latency | Low (Azure backbone) | Higher (encrypted tunnel) |
| Cost | Per GB transferred | Fixed monthly + per GB |
| Cross-region | Yes (global peering) | Yes |
| On-premises | No | Yes |
| Encryption | Azure backbone (private) | IPSec |

We use VNet peering for hub-to-spoke (fast, within Azure). The GatewaySubnet is provisioned for future VPN connectivity to on-premises.

### 13.4 Route Tables

**Azure**: VNet peering automatically adds routes. NSGs filter at the subnet level.

**AWS**: Explicit route tables required:
- Public route table: `0.0.0.0/0 → igw-xxx`
- Private route table: `0.0.0.0/0 → nat-xxx`

### 13.5 Azure NSG vs. AWS Security Groups

| Feature | Azure NSG | AWS Security Group |
|---------|-----------|-------------------|
| Default | Deny all inbound, allow all outbound | Deny all inbound, allow all outbound |
| Stateful | Yes | Yes |
| Rules | Priority-based (100-4096) | All rules evaluated |
| Attachment | Subnet or NIC | Instance (ENI) |
| Deny rules | Supported | Not supported (allow-only) |

---

## 14. Cost Optimization

### 14.1 Dev Environment Savings

- NAT Gateway disabled: Saves ~$32/month + $0.045/GB
- No Application Gateway: Saves ~$175/month (Standard_v2)
- No bastion EC2: Saves ~$8/month (t3.micro)
- 2 AZs instead of 3: Fewer subnet resources

### 14.2 Estimating Costs

| Resource | Monthly Cost (approx.) |
|----------|----------------------|
| Azure VNet + subnets | Free |
| Azure VNet Peering | $0.01/GB |
| Azure NSG | Free |
| Azure App Gateway Standard_v2 | ~$175 + $0.008/GB |
| Azure App Gateway WAF_v2 | ~$350 + $0.008/GB |
| AWS VPC + subnets | Free |
| AWS NAT Gateway | ~$32 + $0.045/GB |
| AWS EC2 t3.micro | ~$8 |
| AWS S3 | ~$0.023/GB |

**Total dev**: ~$0/month (everything is free-tier eligible)
**Total prod**: ~$400-500/month (Gateway + WAF + NAT + Bastion)

---

## 15. Common Interview Questions & Answers

### Terraform

**Q: What happens if two people run `terraform apply` simultaneously?**
A: With remote state in Azure Storage, Terraform acquires a **blob lease** (lock) before writing. The second person gets a "state locked" error and must wait. This prevents state corruption.

**Q: What's the difference between `terraform plan` and `terraform apply`?**
A: `plan` is a dry run — it shows what would change without making any changes. `apply` executes the changes. Best practice: always run `plan` first, review the diff, then `apply`.

**Q: How do you handle secrets in Terraform?**
A: Never hardcode secrets in `.tf` files. Use:
1. Environment variables (`TF_VAR_xxx`)
2. Azure DevOps Variable Groups (encrypted)
3. AWS SSM Parameter Store or Secrets Manager
4. HashiCorp Vault for more complex setups

**Q: What's the blast radius of a `terraform destroy` in this project?**
A: Limited to one environment. Because each environment has its own state file (`dev/terraform.tfstate`, `prod/terraform.tfstate`), destroying dev cannot affect prod.

**Q: Why use modules instead of putting everything in one file?**
A: Modules provide:
1. **Reusability** — same VPC module for dev, staging, prod
2. **Encapsulation** — internal details hidden behind variables/outputs
3. **Testability** — validate each module independently
4. **Reduced blast radius** — changes to one module don't cascade

**Q: What does `terraform init -backend=false` do?**
A: It initializes providers and modules but skips backend configuration. We use this in CI to validate module syntax without needing state storage credentials.

### Networking

**Q: Why hub-spoke instead of a flat network?**
A: Hub-spoke provides:
1. Centralized firewall and gateway (cost sharing)
2. Spoke isolation (workloads can't talk to each other by default)
3. Scalability (add spokes without modifying the hub)
4. Compliance (centralized logging and security controls)

**Q: Why private subnets?**
A: Defense in depth. Databases, internal services, and application backends should never be directly reachable from the internet. They reach out via NAT Gateway, but no one can reach in.

**Q: What's the difference between an NSG and a firewall?**
A: NSGs are Layer 3/4 (IP + port) stateful packet filters. Azure Firewall is Layer 3-7 with FQDN filtering, threat intelligence, TLS inspection, and centralized logging. NSGs are free; Firewall costs ~$900/month.

### CI/CD

**Q: Why plan on PR and apply on merge?**
A: The plan output shows reviewers exactly what infrastructure will change. This is the code review for infrastructure. Apply only happens after review + merge, ensuring no unreviewed changes reach production.

**Q: Why Azure DevOps for Azure and CodePipeline for AWS?**
A: Using native cloud DevOps services means:
1. Best integration with their respective IAM, secrets, and resource APIs
2. No third-party tool to manage, secure, and pay for
3. Demonstrates familiarity with both ecosystems
4. The Azure DevOps pipeline handles Azure resources, while CodePipeline handles AWS resources — matching the cloud provider boundary

**Q: How do you prevent someone from applying to prod accidentally?**
A: Multiple controls:
1. State isolation (per-environment state files)
2. Azure DevOps Environment with approval gate for production
3. AWS CodePipeline manual approval stage with SNS notification
4. Branch protection rules (only merge to main triggers apply)

### Security

**Q: How do you handle the EC2 metadata vulnerability?**
A: IMDSv2 is enforced: `http_tokens = "required"`. This requires a PUT request with a TTL-limited token before accessing metadata, blocking SSRF-based credential theft.

**Q: What's your S3 bucket security posture?**
A: Four layers:
1. AES-256 server-side encryption
2. All four public access block settings enabled
3. Versioning for accidental deletion recovery
4. Lifecycle rules to expire old objects

---

## 16. Troubleshooting Guide

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| "Error acquiring state lock" | Another apply is running | Wait, or force-unlock: `terraform force-unlock <LOCK_ID>` |
| "Subnet not found" | Module dependency issue | Ensure spoke module runs before NSG module (implicit dependency via `module.spoke.subnet_ids`) |
| "CIDR overlap" | Two subnets have the same range | Check CIDR planning table — each env uses different /16 blocks |
| "Provider not found" | Forgot `terraform init` | Run `terraform init` in the environment directory |
| "Backend not initialized" | bootstrap not run | Run bootstrap first, then configure backend in environment |
| "Access denied" | Missing cloud credentials | Check `az login` / `aws configure` or CI/CD env vars |

### Debugging Commands

```bash
# Show current state resources
terraform state list

# Show details of a specific resource
terraform state show module.azure_hub.azurerm_virtual_network.hub

# See what Terraform will do (without applying)
terraform plan

# Format all .tf files
terraform fmt -recursive

# Validate syntax
terraform validate

# Import an existing resource into state
terraform import module.azure_hub.azurerm_resource_group.hub /subscriptions/.../resourceGroups/rg-hub-dev
```

---

## 17. What I Would Add Next

If continuing to build on this project:

1. **Azure Firewall**: Route all spoke-to-spoke and spoke-to-internet traffic through Azure Firewall in the hub
2. **Azure Bastion**: Deploy Bastion in the hub for secure VM access (replacing SSH)
3. **Terraform Cloud/Enterprise**: Migrate from Azure Storage backend to Terraform Cloud for better state management UI, policy-as-code (Sentinel), and cost estimation
4. **Policy-as-Code**: Add OPA/Conftest or Azure Policy to enforce compliance (e.g., "all S3 buckets must have encryption")
5. **Monitoring**: Azure Monitor + AWS CloudWatch for network metrics and alerts
6. **DNS**: Azure Private DNS Zones + AWS Route 53 for private DNS resolution across the hub-spoke
7. **Cross-cloud connectivity**: VPN tunnel between Azure VPN Gateway and AWS Virtual Private Gateway

---

## Summary

This project demonstrates that you can:
- Write modular, reusable Terraform across Azure and AWS
- Design secure hub-spoke and VPC networking topologies
- Manage state remotely with proper locking and isolation
- Build CI/CD pipelines using native DevOps services (Azure DevOps + AWS CodePipeline)
- Apply security best practices (NSGs, WAF, encryption, IMDSv2, deny-by-default)
- Plan CIDR ranges and environment promotion strategies

**The message to a hiring manager**: "I understand infrastructure fundamentals, I can work safely with Terraform, and I think about security, cost, and blast radius — not just making it work."
