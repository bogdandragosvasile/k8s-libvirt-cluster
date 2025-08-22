# variable "kube_ssh_public_key" {
#   description = "SSH public key for kubeadmin user"
#   type        = string
# }

variable "enable_autoscaling" {
  description = "Enable autoscaling infrastructure"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s-cluster"
}

variable "autoscaling_min_nodes" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
  default     = 3
}

variable "autoscaling_max_nodes" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
  default     = 10
}
