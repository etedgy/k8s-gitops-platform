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
  # local state; use remote backend per env in prod
}

provider "kind" {}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}
