locals {
  # static path: avoids provider<->resource dependency
  kubeconfig_path = abspath("${path.module}/.kube/config")
}

module "cluster" {
  source          = "../../modules/kind-cluster"
  cluster_name    = var.cluster_name
  worker_count    = var.worker_count
  kubeconfig_path = local.kubeconfig_path
}

module "addons" {
  source          = "../../modules/addons"
  kubeconfig_path = local.kubeconfig_path
  depends_on      = [module.cluster]
}

output "cluster_name" {
  value = var.cluster_name
}

output "kubeconfig_path" {
  value = local.kubeconfig_path
}
