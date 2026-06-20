terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # kubernetes provider — add back here when you uncomment the provider
    # block below and start managing k8s resources from Terraform:
    #   kubernetes = {
    #     source  = "hashicorp/kubernetes"
    #     version = "~> 2.23"
    #   }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # S3 backend for remote state storage.
  # Values are supplied at init time — do NOT hardcode here.
  # Usage:  terraform init -backend-config=../../backend.tfvars
  backend "s3" {}
}

# ---------------------------------------------------------------------------
# AWS Provider
# default_tags are merged onto every resource that supports them
# ---------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "EKS-Platform"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# ---------------------------------------------------------------------------
# Kubernetes Provider (declared for future use)
# No Kubernetes resources are created in the initial deploy.
# Uncomment and use once the cluster is up and you want to manage k8s
# resources (e.g. ConfigMaps, Deployments) directly from Terraform.
# ---------------------------------------------------------------------------

# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.current.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.current.certificate_authority.data)
#
#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     arguments   = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
#   }
# }
