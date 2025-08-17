# =============================================================================
# Core Infrastructure Variables
# =============================================================================

variable "kube_ssh_public_key" {
  description = "SSH public key for kubeadmin user"
  type        = string
}

# =============================================================================
# Operating System Configuration
# =============================================================================

variable "linux_distro" {
  description = "Linux distribution to use for VMs"
  type        = string
  default     = "ubuntu"
  validation {
    condition = contains([
      "ubuntu-24.04",
      "ubuntu-22.04", 
      "ubuntu-20.04",
      "centos-9",
      "centos-8",
      "rocky-9",
      "rocky-8",
      "debian-12",
      "debian-11",
      "opensuse-15.5",
      "opensuse-15.4"
    ], var.linux_distro)
    error_message = "Supported distros: ubuntu-24.04, ubuntu-22.04, ubuntu-20.04, centos-9, centos-8, rocky-9, rocky-8, debian-12, debian-11, opensuse-15.5, opensuse-15.4"
  }
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_mode" {
  description = "Network mode: 'nat' for isolated network or 'bridge' for bridged network"
  type        = string
  default     = "nat"
  validation {
    condition     = contains(["nat", "bridge"], var.network_mode)
    error_message = "Network mode must be either 'nat' or 'bridge'."
  }
}

variable "bridge_interface" {
  description = "Host bridge interface name for bridge mode (e.g., br0, virbr0)"
  type        = string
  default     = "br0"
}

variable "nat_network_cidr" {
  description = "CIDR block for NAT network mode"
  type        = string
  default     = "192.168.122.0/24"
}

variable "bridge_network_cidr" {
  description = "CIDR block for bridge network mode (should match host network)"
  type        = string
  default     = "192.168.1.0/24"
}

# =============================================================================
# MetalLB Configuration
# =============================================================================

variable "metallb_ip_range" {
  description = "IP range for MetalLB load balancer (auto-calculated based on network mode)"
  type        = string
  default     = ""
}

# =============================================================================
# VM Resource Configuration
# =============================================================================

variable "vm_cpu_cores" {
  description = "Default CPU cores for VMs"
  type        = number
  default     = 2
}

variable "vm_memory_mb" {
  description = "Default memory in MB for VMs"
  type        = number
  default     = 4096
}

# Control plane specific
variable "cp_cpu_cores" {
  description = "CPU cores for control plane nodes"
  type        = number
  default     = 2
}

variable "cp_memory_mb" {
  description = "Memory in MB for control plane nodes"
  type        = number
  default     = 4096
}

# Worker specific
variable "worker_cpu_cores" {
  description = "CPU cores for worker nodes"
  type        = number
  default     = 4
}

variable "worker_memory_mb" {
  description = "Memory in MB for worker nodes" 
  type        = number
  default     = 8192
}

# Load balancer specific
variable "lb_cpu_cores" {
  description = "CPU cores for load balancer nodes"
  type        = number
  default     = 1
}

variable "lb_memory_mb" {
  description = "Memory in MB for load balancer nodes"
  type        = number
  default     = 1024
}

# =============================================================================
# Advanced Configuration
# =============================================================================

variable "enable_cert_manager" {
  description = "Enable cert-manager with Let's Encrypt"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate registration"
  type        = string
  default     = ""
}

variable "letsencrypt_staging" {
  description = "Use Let's Encrypt staging environment (for testing)"
  type        = bool
  default     = true
}
