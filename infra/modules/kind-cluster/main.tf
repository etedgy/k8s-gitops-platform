# Reusable module: a kind (Kubernetes-in-Docker) cluster wired for ingress.
#
# Why kind: it makes the whole environment reproducible on any laptop or CI
# runner with just Docker — no cloud account, no cost, no drift. The same
# module could be swapped for an EKS/AKS/GKE module without touching the
# environment configs that consume its outputs (see infra/environments/*).

resource "kind_cluster" "this" {
  name            = var.cluster_name
  kubeconfig_path = var.kubeconfig_path
  wait_for_ready  = true
  # Pin the node image so clusters are byte-for-byte reproducible across machines.
  node_image = "kindest/node:v1.30.4"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # Control-plane doubles as the ingress node: it carries the
    # `ingress-ready` label and publishes 80/443 to the host so the nginx
    # ingress controller is reachable at http://<host>.
    node {
      role = "control-plane"

      kubeadm_config_patches = [
        <<-EOT
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
        EOT
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = var.ingress_http_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = var.ingress_https_port
        protocol       = "TCP"
      }
    }

    # Worker nodes — count is environment-specific so prod can spread pods
    # across more nodes (see topologySpreadConstraints in the Deployment).
    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }
  }
}
