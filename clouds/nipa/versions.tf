terraform {
  required_version = ">= 1.8"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4"
    }
  }
}

# Credentials come from clouds.yaml + secure.yaml, so they never reach tfvars or state.
provider "openstack" {
  cloud = var.cloud
}
