variable "cluster_name" {
  description = "Name of the kind cluster for this environment."
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
}
