# Complete main.tf for Kubernetes cluster on Libvirt with Ubuntu 24.04 base image
# This provisions: 2 load balancers, 3 control planes, 3 workers
# Assumes cloud_init_user_data.tpl and cloud_init_network_config.tpl are in the same directory
# Adjust variables, IPs, memory/vcpu, etc., as needed for your setup

provider "libvirt" {
  uri = "qemu:///system"  # Connect to local Libvirt
}

# Variables
variable "kube_ssh_public_key" {
  description = "SSH public key for VMs"
  type        = string
}

variable "gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "172.16.16.1"
}

variable "dns" {
  description = "DNS server IP"
  type        = string
  default     = "8.8.8.8"
}

# Base Ubuntu image (pre-downloaded)
resource "libvirt_volume" "base" {
  name   = "ubuntu-24.04-server-cloudimg-amd64.img"
  source = "/var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img"  # Path to the new image
  format = "qcow2"
  pool   = "default"
}

# --- Load Balancers (2 VMs) ---
locals {
  lb_vms = [
    { name = "loadbalancer1", ip = "172.16.16.51", memory = 1024, vcpu = 1 },
    { name = "loadbalancer2", ip = "172.16.16.52", memory = 1024, vcpu = 1 }
  ]
}

resource "libvirt_volume" "lb" {
  count            = length(local.lb_vms)
  name             = "${local.lb_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 10737418240  # 10 GB
}

data "template_file" "lb_user_data" {
  count    = length(local.lb_vms)
  template = file("${path.module}/cloud_init_user_data.tpl")

  vars = {
    hostname   = local.lb_vms[count.index].name
    public_key = var.kube_ssh_public_key
  }
}

data "template_file" "lb_network_config" {
  count    = length(local.lb_vms)
  template = file("${path.module}/cloud_init_network_config.tpl")

  vars = {
    ip      = local.lb_vms[count.index].ip
    gateway = var.gateway
    dns     = var.dns
  }
}

resource "libvirt_cloudinit_disk" "lb" {
  count          = length(local.lb_vms)
  name           = "${local.lb_vms[count.index].name}-cloudinit.iso"
  user_data      = data.template_file.lb_user_data[count.index].rendered
  network_config = data.template_file.lb_network_config[count.index].rendered
  pool           = "default"
}

resource "libvirt_domain" "lb" {
  count  = length(local.lb_vms)
  name   = local.lb_vms[count.index].name
  memory = local.lb_vms[count.index].memory
  vcpu   = local.lb_vms[count.index].vcpu

  cloudinit = libvirt_cloudinit_disk.lb[count.index].id

  disk {
    volume_id = libvirt_volume.lb[count.index].id
  }

  network_interface {
    network_name = "default"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# --- Control Planes (3 VMs) ---
locals {
  cp_vms = [
    { name = "kcontrolplane1", ip = "172.16.16.101", memory = 4096, vcpu = 2 },
    { name = "kcontrolplane2", ip = "172.16.16.102", memory = 4096, vcpu = 2 },
    { name = "kcontrolplane3", ip = "172.16.16.103", memory = 4096, vcpu = 2 }
  ]
}

resource "libvirt_volume" "cp" {
  count            = length(local.cp_vms)
  name             = "${local.cp_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 21474836480  # 20 GB for control planes
}

data "template_file" "cp_user_data" {
  count    = length(local.cp_vms)
  template = file("${path.module}/cloud_init_user_data.tpl")

  vars = {
    hostname   = local.cp_vms[count.index].name
    public_key = var.kube_ssh_public_key
  }
}

data "template_file" "cp_network_config" {
  count    = length(local.cp_vms)
  template = file("${path.module}/cloud_init_network_config.tpl")

  vars = {
    ip      = local.cp_vms[count.index].ip
    gateway = var.gateway
    dns     = var.dns
  }
}

resource "libvirt_cloudinit_disk" "cp" {
  count          = length(local.cp_vms)
  name           = "${local.cp_vms[count.index].name}-cloudinit.iso"
  user_data      = data.template_file.cp_user_data[count.index].rendered
  network_config = data.template_file.cp_network_config[count.index].rendered
  pool           = "default"
}

resource "libvirt_domain" "cp" {
  count  = length(local.cp_vms)
  name   = local.cp_vms[count.index].name
  memory = local.cp_vms[count.index].memory
  vcpu   = local.cp_vms[count.index].vcpu

  cloudinit = libvirt_cloudinit_disk.cp[count.index].id

  disk {
    volume_id = libvirt_volume.cp[count.index].id
  }

  network_interface {
    network_name = "default"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# --- Workers (3 VMs) ---
locals {
  worker_vms = [
    { name = "kworker1", ip = "172.16.16.201", memory = 8192, vcpu = 4 },
    { name = "kworker2", ip = "172.16.16.202", memory = 8192, vcpu = 4 },
    { name = "kworker3", ip = "172.16.16.203", memory = 8192, vcpu = 4 }
  ]
}

resource "libvirt_volume" "worker" {
  count            = length(local.worker_vms)
  name             = "${local.worker_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 32212254720  # 30 GB for workers
}

data "template_file" "worker_user_data" {
  count    = length(local.worker_vms)
  template = file("${path.module}/cloud_init_user_data.tpl")

  vars = {
    hostname   = local.worker_vms[count.index].name
    public_key = var.kube_ssh_public_key
  }
}

data "template_file" "worker_network_config" {
  count    = length(local.worker_vms)
  template = file("${path.module}/cloud_init_network_config.tpl")

  vars = {
    ip      = local.worker_vms[count.index].ip
    gateway = var.gateway
    dns     = var.dns
  }
}

resource "libvirt_cloudinit_disk" "worker" {
  count          = length(local.worker_vms)
  name           = "${local.worker_vms[count.index].name}-cloudinit.iso"
  user_data      = data.template_file.worker_user_data[count.index].rendered
  network_config = data.template_file.worker_network_config[count.index].rendered
  pool           = "default"
}

resource "libvirt_domain" "worker" {
  count  = length(local.worker_vms)
  name   = local.worker_vms[count.index].name
  memory = local.worker_vms[count.index].memory
  vcpu   = local.worker_vms[count.index].vcpu

  cloudinit = libvirt_cloudinit_disk.worker[count.index].id

  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }

  network_interface {
    network_name = "default"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Generate Ansible inventory.ini
data "template_file" "inventory" {
  template = file("${path.module}/inventory.tpl")

  vars = {
    lb1_ip        = libvirt_domain.lb[0].network_interface[0].addresses[0]
    lb2_ip        = libvirt_domain.lb[1].network_interface[0].addresses[0]
    cp1_ip        = libvirt_domain.cp[0].network_interface[0].addresses[0]
    cp2_ip        = libvirt_domain.cp[1].network_interface[0].addresses[0]
    cp3_ip        = libvirt_domain.cp[2].network_interface[0].addresses[0]
    worker1_ip    = libvirt_domain.worker[0].network_interface[0].addresses[0]
    worker2_ip    = libvirt_domain.worker[1].network_interface[0].addresses[0]
    worker3_ip    = libvirt_domain.worker[2].network_interface[0].addresses[0]
  }
}

resource "local_file" "inventory" {
  content  = data.template_file.inventory.rendered
  filename = "${path.module}/../ansible/inventory.ini"
}

# Outputs
output "vm_ips" {
  value = {
    loadbalancer1 = libvirt_domain.lb[0].network_interface[0].addresses[0]
    loadbalancer2 = libvirt_domain.lb[1].network_interface[0].addresses[0]
    kcontrolplane1 = libvirt_domain.cp[0].network_interface[0].addresses[0]
    kcontrolplane2 = libvirt_domain.cp[1].network_interface[0].addresses[0]
    kcontrolplane3 = libvirt_domain.cp[2].network_interface[0].addresses[0]
    kworker1 = libvirt_domain.worker[0].network_interface[0].addresses[0]
    kworker2 = libvirt_domain.worker[1].network_interface[0].addresses[0]
    kworker3 = libvirt_domain.worker[2].network_interface[0].addresses[0]
  }
  description = "IPs of all provisioned VMs"
}

output "ansible_inventory_path" {
  value = local_file.inventory.filename
  description = "Path to generated Ansible inventory file"
}
