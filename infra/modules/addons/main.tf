# Cluster addons: ingress-nginx (external exposure) + metrics-server (feeds the HPA).

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

  # Run on the ingress-ready control-plane node and publish via hostPort (kind).
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

  # kind's kubelet certs are self-signed; not needed on managed clusters.
  values = [yamlencode({
    args = ["--kubelet-insecure-tls"]
  })]
}
