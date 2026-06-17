# Terraform AWS EKS Platform Cluster

Provisions a managed Kubernetes cluster on AWS EKS using Terraform. Designed with a weekend-only schedule (Sat & Sun, 8 AM – 12 PM Jakarta / WIB) to keep costs low.

> **Planning & design decisions** are documented in [`README.md - Terraform EKS Cluster.md`](./README.md%20-%20Terraform%20EKS%20Cluster.md).

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Prerequisites](#2-prerequisites)
3. [Bootstrap — S3 Backend](#3-bootstrap--s3-backend)
4. [Configuration](#4-configuration)
   - [backend.tfvars](#41-backendtfvars)
   - [terraform.tfvars](#42-terraformtfvars)
   - [All Available Variables](#43-all-available-variables)
5. [Deploy](#5-deploy)
6. [Connect kubectl](#6-connect-kubectl)
7. [Verify the Cluster](#7-verify-the-cluster)
8. [Scheduler — Manual Start / Stop](#8-scheduler--manual-start--stop)
9. [Tear Down](#9-tear-down)
10. [Module Overview](#10-module-overview)
11. [Outputs Reference](#11-outputs-reference)
12. [Backlog](#12-backlog)

---

## 1. Project Structure

```
.
├── backend.tfvars.example          # Template for S3 backend config
├── .gitignore
│
├── modules/                        # Reusable module definitions
│   ├── vpc/                        #   VPC, subnets, NAT, IGW
│   ├── node-groups/                #   Node IAM role + managed node group config
│   ├── eks/                        #   EKS cluster, OIDC, addons
│   └── scheduler/                  #   EventBridge + Lambda start/stop
│
├── environments/
│   ├── env-development/            # <-- active environment (t3.medium nodes)
│   │   ├── versions.tf             #   provider & backend declarations
│   │   ├── variables.tf            #   input variables
│   │   ├── main.tf                 #   wires the four modules together
│   │   └── outputs.tf              #   post-apply outputs
│   └── env-staging/                # <-- staging environment (t3.large nodes)
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       └── outputs.tf
│
├── scripts/
│   ├── update-kubeconfig-dev.sh    # Configures kubectl for env-development
│   ├── update-kubeconfig-staging.sh# Configures kubectl for env-staging
│   ├── cleanup-dev.sh              # Full teardown for env-development
│   └── cleanup-staging.sh          # Full teardown for env-staging
│
└── README.md - Terraform EKS Cluster.md   # Requirements / design doc
```

---

## 2. Prerequisites

| Tool | Minimum Version | Purpose |
|---|---|---|
| Terraform | 1.11.0 | Infrastructure provisioning |
| AWS CLI | 2.0 | Auth, backend bootstrap, kubectl token |
| kubectl | 1.28 | Cluster interaction after deploy |

AWS credentials must be configured (`aws configure` or environment variables). The IAM identity you use needs permissions to create VPCs, EC2 instances, IAM roles, EKS clusters, Lambda functions, and EventBridge rules.

---

## 3. Bootstrap — S3 Backend

Terraform state is stored remotely using S3 native locking (Terraform >= 1.11) — no DynamoDB table needed. The S3 bucket must exist **before** the first `terraform init`. Create one per environment:

```bash
# env-development bucket
aws s3api create-bucket \
  --bucket eks-tf-state-env-development \
  --region ap-southeast-3 \
  --create-bucket-configuration LocationConstraint=ap-southeast-3

aws s3api put-bucket-versioning \
  --bucket eks-tf-state-env-development \
  --versioning-configuration Status=Enabled

# env-staging bucket
aws s3api create-bucket \
  --bucket eks-tf-state-env-staging \
  --region ap-southeast-3 \
  --create-bucket-configuration LocationConstraint=ap-southeast-3

aws s3api put-bucket-versioning \
  --bucket eks-tf-state-env-staging \
  --versioning-configuration Status=Enabled
```

> Bucket names must use the `eks-tf-*` prefix — that's the scope of the IAM policy.

---

## 4. Configuration

### 4.1 backend.tfvars

This file tells Terraform where to store state. It is **gitignored** — never commit it.

```bash
cp backend.tfvars.example backend.tfvars
```

Open `backend.tfvars` and fill in the bucket name for your target environment:

```hcl
# env-development
bucket       = "eks-tf-state-env-development"
key          = "eks-env-development/terraform.tfstate"
region       = "ap-southeast-3"
encrypt      = true
use_lockfile = true

# env-staging (use a separate backend.tfvars or override at init time)
# key = "eks-env-staging/terraform.tfstate"
# bucket = "eks-tf-state-env-staging"
```

### 4.2 terraform.tfvars

This file holds your environment-specific values. It is also **gitignored**.

```bash
# Create it inside the target environment directory
cat > environments/env-development/terraform.tfvars << 'EOF'
cluster_name = "my-eks-dev-cluster"
EOF
```

`cluster_name` is the only **required** variable — everything else has a sensible default. Override anything you need using the table in 4.3.

### 4.3 All Available Variables

| Variable | env-development default | env-staging default | Description |
|---|---|---|---|
| `cluster_name` | *(required)* | *(required)* | EKS cluster name. Used in every resource name. |
| `aws_region` | `ap-southeast-3` | `ap-southeast-3` | AWS region for all resources |
| `cluster_version` | `1.28` | `1.28` | Kubernetes version |
| `vpc_cidr` | `10.0.0.0/16` | `10.0.0.0/16` | VPC CIDR block |
| `availability_zones` | `["ap-southeast-3a", "ap-southeast-3b"]` | `["ap-southeast-3a", "ap-southeast-3b"]` | AZs (minimum 2) |
| `node_instance_type` | `t3.medium` | `t3.large` | EC2 instance type for worker nodes |
| `node_min_size` | `2` | `2` | ASG minimum nodes |
| `node_desired_size` | `2` | `2` | ASG desired nodes |
| `node_max_size` | `5` | `5` | ASG maximum nodes |
| `scheduler_enabled` | `true` | `true` | Set `false` to disable the weekend start/stop automation |

---

## 5. Deploy

All commands are run from the **repo root** unless noted.

```bash
# 1. Initialise — downloads providers, connects to S3 backend
cd environments/env-development
terraform init -backend-config=../../backend.tfvars

# 2. Validate syntax
terraform validate

# 3. Review the plan (nothing is created yet)
terraform plan

# 4. Apply — creates all AWS resources
terraform apply
```

Typical apply time is 10–15 minutes, dominated by EKS control-plane provisioning.

---

## 6. Connect kubectl

After a successful apply, configure your local `kubectl`:

**Option A — use the convenience output:**

```bash
# Still inside environments/env-development/
terraform output -raw update_kubeconfig_command
# Copy and run the printed command, e.g.:
# aws eks update-kubeconfig --name my-eks-dev-cluster --region ap-southeast-3
```

**Option B — run the helper script from the repo root:**

```bash
cd ../..                        # back to repo root
bash scripts/update-kubeconfig-dev.sh
```

---

## 7. Verify the Cluster

```bash
# List nodes — expect 2 nodes in Ready state
kubectl get nodes

# Quick smoke test — deploy and hit a test pod
kubectl run nginx --image=nginx --port=80 --expose
kubectl get pods
kubectl get svc nginx
```

Clean up the test resources when done:

```bash
kubectl delete pod nginx
kubectl delete svc nginx
```

---

## 8. Scheduler — Manual Start / Stop

The scheduler automatically starts and stops worker nodes every weekend (Jakarta WIB):

| Day | Start | Stop |
|---|---|---|
| Saturday | 8:00 AM WIB (01:00 UTC) | 12:00 PM WIB (05:00 UTC) |
| Sunday | 8:00 AM WIB (01:00 UTC) | 12:00 PM WIB (05:00 UTC) |

If you need to start or stop the nodes **outside** the schedule, invoke the Lambda functions manually:

```bash
# Get the Lambda function names from Terraform outputs
cd environments/env-development
terraform output scheduler_start_lambda_arn
terraform output scheduler_stop_lambda_arn

# Stop nodes now
aws lambda invoke \
  --function-name <cluster_name>-scheduler-stop \
  --region ap-southeast-3 \
  /dev/stdout

# Start nodes now
aws lambda invoke \
  --function-name <cluster_name>-scheduler-start \
  --region ap-southeast-3 \
  /dev/stdout
```

Replace `<cluster_name>` with the value you set in `terraform.tfvars`.

To disable the scheduler entirely, set `scheduler_enabled = false` in `terraform.tfvars` and re-run `terraform apply`. This removes all EventBridge rules and Lambda functions — you would manage node scaling manually via `node_desired_size`.

---

## 9. Tear Down

Destroys everything Terraform created. The S3 bucket is **not** touched (it holds the state) — see the script output for instructions on removing it manually if needed.

```bash
# env-development
bash scripts/cleanup-dev.sh

# env-staging
bash scripts/cleanup-staging.sh
```

Or manually:

```bash
cd environments/env-development
terraform destroy
```

---

## 10. Module Overview

The four modules are wired in a strict dependency order — no circular references:

```
module.vpc  →  module.node_groups  →  module.eks  →  module.scheduler
```

| Module | Responsibility |
|---|---|
| `modules/vpc` | VPC, public & private subnets, single NAT Gateway, Internet Gateway, EKS subnet tags. Wraps `terraform-aws-modules/vpc/aws`. |
| `modules/node-groups` | Node IAM role (EC2 trust, 3 AWS managed policies) and the managed node group configuration map. Owns the role so it can be included in the config map without a circular dependency. |
| `modules/eks` | Cluster IAM role, EKS cluster itself (via `terraform-aws-modules/eks/aws`), OIDC provider for future IRSA, and the three core managed addons (`vpc-cni`, `kube-proxy`, `coredns`). |
| `modules/scheduler` | Two Python Lambda functions (start / stop) packaged inline, four EventBridge rules (Sat/Sun × start/stop), and the associated IAM permissions. All resources are gated by `var.enabled`. |

---

## 11. Outputs Reference

After `terraform apply`, these values are available via `terraform output`:

| Output | Description |
|---|---|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | Kubernetes API server URL |
| `cluster_ca_data` | Base64 CA certificate (sensitive) |
| `oidc_provider_arn` | OIDC provider ARN (for IRSA service accounts) |
| `vpc_id` | VPC ID |
| `aws_region` | Region the cluster was deployed into |
| `update_kubeconfig_command` | Ready-to-paste `aws eks update-kubeconfig` command |
| `scheduler_start_lambda_arn` | ARN of the start Lambda (for manual invocation) |
| `scheduler_stop_lambda_arn` | ARN of the stop Lambda (for manual invocation) |

---

## 12. Backlog

Items that are not blocking deployment but are planned for future enhancement.

| Feature | Priority | Notes |
|---|---|---|
| GitHub Actions CI/CD | Low | `terraform validate`, `fmt`, `plan` checks on PR |
| Makefile | Low | Convenience wrapper for common commands |
| Terraform tests | Medium | `terraform test` framework or Terratest |
| Budget / Cost alerts | Medium | CloudWatch alarms for AWS spend |
| Kubernetes manifests | High | App deployments — separate concern / repo |
| Monitoring & Logging | High | CloudWatch Container Insights |
| Cluster Autoscaler | Medium | More dynamic scaling than the weekend scheduler |
