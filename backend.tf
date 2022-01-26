terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.37"
    }
  }
  required_version = "~> 0.15"

  backend "remote" {
    organization = "eoo_aws"

    workspaces {
      name = "eoo_consul"
    }
  }
}
