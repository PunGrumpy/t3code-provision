terraform {
  required_version = ">= 1.8"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.52"
    }
  }
}

# The provider reads HCLOUD_TOKEN, so the token never reaches tfvars or state.
provider "hcloud" {}
