variable "ingress_nginx_version" {
  type    = string
  default = "4.11.2"
}

variable "metrics_server_version" {
  type    = string
  default = "3.12.1"
}

variable "argocd_version" {
  type    = string
  default = "7.6.12"
}

variable "argo_rollouts_version" {
  type    = string
  default = "2.37.3"
}

variable "prometheus_version" {
  type    = string
  default = "25.27.0"
}

variable "cilium_version" {
  type    = string
  default = "1.16.3"
}

# CNI + network-policy enforcement. Installed first: nodes are NotReady without
# it (default CNI is disabled), so every other addon depends on it.
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = "kube-system"

  # kind-friendly settings (Cilium keeps kube-proxy; k8s IPAM).
  values = [yamlencode({
    ipam     = { mode = "kubernetes" }
    image    = { pullPolicy = "IfNotPresent" }
    hubble   = { relay = { enabled = true }, ui = { enabled = true } }
    operator = { replicas = 1 }
  })]
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  namespace        = "ingress-nginx"
  create_namespace = true
  depends_on       = [helm_release.cilium]

  # kind: run on ingress-ready node via hostPort
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
  depends_on       = [helm_release.cilium]

  # kind only: self-signed kubelet certs
  values = [yamlencode({
    args = ["--kubelet-insecure-tls"]
  })]
}

# GitOps CD controller.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true
  depends_on       = [helm_release.cilium]
}

# Progressive-delivery controller (drives the Rollout canary).
resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = var.argo_rollouts_version
  namespace        = "argo-rollouts"
  create_namespace = true
  depends_on       = [helm_release.cilium]
}

# Metrics backend the canary AnalysisTemplate queries.
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = var.prometheus_version
  namespace        = "monitoring"
  create_namespace = true
  depends_on       = [helm_release.cilium]
}
