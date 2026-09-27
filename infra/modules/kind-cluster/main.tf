resource "kind_cluster" "this" {
  name            = var.cluster_name
  kubeconfig_path = var.kubeconfig_path
  wait_for_ready  = true
  node_image      = "kindest/node:v1.30.4"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # control-plane = ingress node
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

    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }
  }
}
