# Cluster addons that the application relies on:
#   * ingress-nginx  -> external exposure (Ingress -> Service -> pods)
#   * metrics-server -> CPU/memory metrics that the HorizontalPodAutoscaler needs
#
# These are cluster-scoped platform concerns, kept separate from the app so the
# same app manifests run on a managed cluster (EKS/AKS/GKE) where the platform
# team owns ingress and metrics instead.

variable "ingress_nginx_version" {
  type    = string
  default = "4.11.2"
}

variable "metrics_server_version" {
  type    = string
  default = "3.12.1"
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  namespace        = "ingress-nginx"
  create_namespace = true

  # kind-specific wiring: run the controller on the ingress-ready control-plane
  # node and publish via hostPort so it is reachable on the mapped host ports.
  values = [yamlencode({
    controller = {
      hostPort     = { enabled = true }
      service      = { type = "NodePort" }
      nodeSelector = { "ingress-ready" = "true" }
      tolerations = [{
        key      = "node-role.kubernetes.io/control-plane"
        operator = "Equal"
        effect   = "NoSchedule"
      }]
    }
  })]
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = var.metrics_server_version
  namespace        = "kube-system"
  create_namespace = false

  # kind's kubelet serving certs are self-signed, so the metrics-server needs
  # --kubelet-insecure-tls locally. This flag is NOT used on managed clusters.
  values = [yamlencode({
    args = ["--kubelet-insecure-tls"]
  })]
}
