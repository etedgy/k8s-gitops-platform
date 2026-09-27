terraform {
  required_version = ">= 1.5"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.9"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  # State is local for this exercise. In a real setup this would be a remote
  # backend with locking, one state per environment, e.g.:
  #   backend "s3" { bucket=... key="dev/terraform.tfstate" dynamodb_table=... }
  # (see infra/environments/README.md).
}

provider "kind" {}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}
