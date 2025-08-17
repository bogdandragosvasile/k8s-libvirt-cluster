terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.3"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# =============================================================================
# Network Resource Creation
# =============================================================================

# Create custom network for NAT mode only
resource "libvirt_network" "k8s_network" {
  count     = var.network_mode == "nat" ? 1 : 0
  name      = "k8s-cluster-network"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = [local.network_config.network_cidr]
  
  dns {
    enabled    = true
    local_only = false
  }
  
  dhcp {
    enabled = true
  }
}

# =============================================================================
# Base Image Management
# =============================================================================

resource "libvirt_volume" "base" {
  name   = "${local.selected_distro.name}.img"
  source = "/var/lib/libvirt/images/${local.selected_distro.name}.img"
  format = "qcow2"
  pool   = "default"
}

# =============================================================================
# VM Volume Creation
# =============================================================================

# Load balancer volumes
resource "libvirt_volume" "lb" {
  count            = length(local.vm_ips.lb_vms)
  name             = "${local.vm_ips.lb_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 10737418240 # 10GB
}

# Control plane volumes
resource "libvirt_volume" "cp" {
  count            = length(local.vm_ips.cp_vms)
  name             = "${local.vm_ips.cp_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 21474836480 # 20GB
}

# Worker volumes
resource "libvirt_volume" "worker" {
  count            = length(local.vm_ips.worker_vms)
  name             = "${local.vm_ips.worker_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 32212254720 # 30GB
}

# =============================================================================
# Cloud-Init Disk Creation  
# =============================================================================

# Load balancer cloud-init disks
resource "libvirt_cloudinit_disk" "lb" {
  count          = length(local.vm_ips.lb_vms)
  name           = "${local.vm_ips.lb_vms[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init_user_data.tpl", {
    hostname      = local.vm_ips.lb_vms[count.index].name,
    public_key    = var.kube_ssh_public_key,
    default_user  = local.selected_distro.user,
    distro_family = local.selected_distro.family,
    package_mgr   = local.selected_distro.package_mgr
  })
  network_config = templatefile("${path.module}/cloud_init_network_config.tpl", {
    ip      = local.vm_ips.lb_vms[count.index].ip,
    gateway = local.network_config.gateway,
    dns     = join(",", local.network_config.dns_servers)
  })
  pool           = "default"
}

# Control plane cloud-init disks
resource "libvirt_cloudinit_disk" "cp" {
  count          = length(local.vm_ips.cp_vms)
  name           = "${local.vm_ips.cp_vms[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init_user_data.tpl", {
    hostname      = local.vm_ips.cp_vms[count.index].name,
    public_key    = var.kube_ssh_public_key,
    default_user  = local.selected_distro.user,
    distro_family = local.selected_distro.family,
    package_mgr   = local.selected_distro.package_mgr
  })
  network_config = templatefile("${path.module}/cloud_init_network_config.tpl", {
    ip      = local.vm_ips.cp_vms[count.index].ip,
    gateway = local.network_config.gateway,
    dns     = join(",", local.network_config.dns_servers)
  })
  pool           = "default"
}

# Worker cloud-init disks
resource "libvirt_cloudinit_disk" "worker" {
  count          = length(local.vm_ips.worker_vms)
  name           = "${local.vm_ips.worker_vms[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init_user_data.tpl", {
    hostname      = local.vm_ips.worker_vms[count.index].name,
    public_key    = var.kube_ssh_public_key,
    default_user  = local.selected_distro.user,
    distro_family = local.selected_distro.family,
    package_mgr   = local.selected_distro.package_mgr
  })
  network_config = templatefile("${path.module}/cloud_init_network_config.tpl", {
    ip      = local.vm_ips.worker_vms[count.index].ip,
    gateway = local.network_config.gateway,
    dns     = join(",", local.network_config.dns_servers)
  })
  pool           = "default"
}

# =============================================================================
# VM Domain Creation
# =============================================================================

# Load balancer VMs
resource "libvirt_domain" "lb" {
  count       = length(local.vm_ips.lb_vms)
  name        = local.vm_ips.lb_vms[count.index].name
  memory      = local.vm_ips.lb_vms[count.index].memory
  vcpu        = local.vm_ips.lb_vms[count.index].vcpu
  qemu_agent  = true

  cloudinit = libvirt_cloudinit_disk.lb[count.index].id

  disk {
    volume_id = libvirt_volume.lb[count.index].id
  }

  network_interface {
    network_name   = var.network_mode == "nat" ? libvirt_network.k8s_network[0].name : var.bridge_interface
    wait_for_lease = true
    addresses      = [local.vm_ips.lb_vms[count.index].ip]
  }
}

# Control plane VMs
resource "libvirt_domain" "cp" {
  count       = length(local.vm_ips.cp_vms)
  name        = local.vm_ips.cp_vms[count.index].name
  memory      = local.vm_ips.cp_vms[count.index].memory
  vcpu        = local.vm_ips.cp_vms[count.index].vcpu
  qemu_agent  = true

  cloudinit = libvirt_cloudinit_disk.cp[count.index].id

  disk {
    volume_id = libvirt_volume.cp[count.index].id
  }

  network_interface {
    network_name   = var.network_mode == "nat" ? libvirt_network.k8s_network[0].name : var.bridge_interface
    wait_for_lease = true
    addresses      = [local.vm_ips.cp_vms[count.index].ip]
  }
}

# Worker VMs
resource "libvirt_domain" "worker" {
  count       = length(local.vm_ips.worker_vms)
  name        = local.vm_ips.worker_vms[count.index].name
  memory      = local.vm_ips.worker_vms[count.index].memory
  vcpu        = local.vm_ips.worker_vms[count.index].vcpu
  qemu_agent  = true

  cloudinit = libvirt_cloudinit_disk.worker[count.index].id

  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }

  network_interface {
    network_name   = var.network_mode == "nat" ? libvirt_network.k8s_network[0].name : var.bridge_interface
    wait_for_lease = true
    addresses      = [local.vm_ips.worker_vms[count.index].ip]
  }
}

# =============================================================================
# Ansible Inventory Generation
# =============================================================================

data "template_file" "inventory" {
  template = file("${path.module}/inventory.tpl")

  vars = {
    lb1_ip      = local.vm_ips.lb_vms[0].ip
    lb2_ip      = local.vm_ips.lb_vms[1].ip
    cp1_ip      = local.vm_ips.cp_vms[0].ip
    cp2_ip      = local.vm_ips.cp_vms[1].ip
    cp3_ip      = local.vm_ips.cp_vms[2].ip
    worker1_ip  = local.vm_ips.worker_vms[0].ip
    worker2_ip  = local.vm_ips.worker_vms[1].ip
    worker3_ip  = local.vm_ips.worker_vms[2].ip
    default_user = local.selected_distro.user
  }
}

resource "local_file" "inventory" {
  content  = data.template_file.inventory.rendered
  filename = "${path.module}/../ansible/inventory.ini"
}

# =============================================================================
# Outputs
# =============================================================================

output "vm_ips" {
  description = "IP addresses of all VMs"
  value = merge(
    { for vm in local.vm_ips.lb_vms : vm.name => vm.ip },
    { for vm in local.vm_ips.cp_vms : vm.name => vm.ip },
    { for vm in local.vm_ips.worker_vms : vm.name => vm.ip }
  )
}

output "virtual_ip" {
  description = "Virtual IP for load balancer"
  value = local.vm_ips.virtual_ip
}

output "network_config" {
  description = "Network configuration details"
  value = {
    mode           = local.network_config.mode
    cidr           = local.network_config.network_cidr
    gateway        = local.network_config.gateway
    metallb_range  = local.network_config.metallb_range
  }
}

output "distro_info" {
  description = "Selected Linux distribution information"
  value = {
    name         = var.linux_distro
    user         = local.selected_distro.user
    package_mgr  = local.selected_distro.package_mgr
    family       = local.selected_distro.family
  }
}

output "cluster_access" {
  description = "Cluster access information"
  value = {
    api_endpoint     = "${local.vm_ips.virtual_ip}:6443"
    ssh_user         = local.selected_distro.user
    control_plane_ip = local.vm_ips.cp_vms[0].ip
  }
}
