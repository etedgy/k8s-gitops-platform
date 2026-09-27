# Environment: DEV. Thin wiring only; reusable logic lives in ../../modules.

locals {
  # Static path so the provider config below has no resource dependency.
  kubeconfig_path = abspath("${path.module}/.kube/config")
}

module "cluster" {
  source          = "../../modules/kind-cluster"
  cluster_name    = var.cluster_name
  worker_count    = var.worker_count
  kubeconfig_path = local.kubeconfig_path
}

module "addons" {
  source     = "../../modules/addons"
  depends_on = [module.cluster]
}

output "cluster_name" {
  value = var.cluster_name
}

output "kubeconfig_path" {
  value = local.kubeconfig_path
}
