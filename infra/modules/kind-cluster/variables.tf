variable "cluster_name" {
  description = "Name of the kind cluster."
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes (in addition to the control-plane)."
  type        = number
  default     = 1
}

variable "ingress_http_port" {
  description = "Host port mapped to the ingress controller's HTTP (80) node port."
  type        = number
  default     = 80
}

variable "ingress_https_port" {
  description = "Host port mapped to the ingress controller's HTTPS (443) node port."
  type        = number
  default     = 443
}

variable "kubeconfig_path" {
  description = "Where to write the generated kubeconfig for this cluster."
  type        = string
}
