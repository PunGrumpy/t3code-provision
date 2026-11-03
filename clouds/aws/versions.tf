terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Credentials come from the usual AWS chain (AWS_PROFILE, SSO, env), never from tfvars.
provider "aws" {
  region = var.region
}
