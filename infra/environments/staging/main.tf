# ---------------------------------------------------------------------------
# Environment: STAGING
# This file is deliberately thin. All reusable logic lives in ../../modules.
# Environment-specific values live in terraform.tfvars. Swapping the cluster
# module for a cloud module would not change the app or the CI/CD pipeline.
# ---------------------------------------------------------------------------

locals {
  # Static path (not a resource output) so the provider config below has no
  # dependency on a resource — the classic kind+helm bootstrap ordering fix.
  kubeconfig_path = abspath("${path.module}/.kube/config")
}

module "cluster" {
  source          = "../../modules/kind-cluster"
  cluster_name    = var.cluster_name
  worker_count    = var.worker_count
  kubeconfig_path = local.kubeconfig_path
}

module "addons" {
  source = "../../modules/addons"
  # Ensure the cluster (and its kubeconfig file) exist before Helm runs.
  depends_on = [module.cluster]
}

output "cluster_name" {
  value = var.cluster_name
}

output "kubeconfig_path" {
  value = local.kubeconfig_path
}
