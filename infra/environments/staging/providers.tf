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
  # Local state for the exercise; use a remote backend per env in production.
}

provider "kind" {}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}
