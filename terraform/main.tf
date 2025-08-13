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

variable "kube_ssh_public_key" {
  description = "SSH public key for VMs"
  type        = string
}

variable "gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.122.1"
}

variable "dns" {
  description = "DNS server IP"
  type        = string
  default     = "8.8.8.8"
}

resource "libvirt_volume" "base" {
  name   = "ubuntu-24.04-server-cloudimg-amd64.img"
  source = "/var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img"
  format = "qcow2"
  pool   = "default"
}

locals {
  lb_vms = [
    { name = "loadbalancer1", ip = "192.168.122.51", memory = 1024, vcpu = 1 },
    { name = "loadbalancer2", ip = "192.168.122.52", memory = 1024, vcpu = 1 }
  ]
  cp_vms = [
    { name = "kcontrolplane1", ip = "192.168.122.101", memory = 4096, vcpu = 2 },
    { name = "kcontrolplane2", ip = "192.168.122.102", memory = 4096, vcpu = 2 },
    { name = "kcontrolplane3", ip = "192.168.122.103", memory = 4096, vcpu = 2 }
  ]
  worker_vms = [
    { name = "kworker1", ip = "192.168.122.201", memory = 8192, vcpu = 4 },
    { name = "kworker2", ip = "192.168.122.202", memory = 8192, vcpu = 4 },
    { name = "kworker3", ip = "192.168.122.203", memory = 8192, vcpu = 4 }
  ]
}

# -------- Function to create VM sets --------

# Creates volumes
resource "libvirt_volume" "lb" {
  count            = length(local.lb_vms)
  name             = "${local.lb_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 10737418240
}

resource "libvirt_volume" "cp" {
  count            = length(local.cp_vms)
  name             = "${local.cp_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 21474836480
}

resource "libvirt_volume" "worker" {
  count            = length(local.worker_vms)
  name             = "${local.worker_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 32212254720
}

# Creates cloud-init disks
resource "libvirt_cloudinit_disk" "lb" {
  count          = length(local.lb_vms)
  name           = "${local.lb_vms[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init_user_data.tpl", {
    hostname   = local.lb_vms[count.index].name,
    public_key = var.kube_ssh_public_key
  })
  network_config = templatefile("${path.module}/cloud_init_network_config.tpl", {
    ip      = local.lb_vms[count.index].ip,
    gateway = var.gateway,
    dns     = var.dns
  })
  pool           = "default"
}

resource "libvirt_cloudinit_disk" "cp" {
  count          = length(local.cp_vms)
  name           = "${local.cp_vms[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init_user_data.tpl", {
    hostname   = local.cp_vms[count.index].name,
    public_key = var.kube_ssh_public_key
  })
  network_config = templatefile("${path.module}/cloud_init_network_config.tpl", {
    ip      = local.cp_vms[count.index].ip,
    gateway = var.gateway,
    dns     = var.dns
  })
  pool           = "default"
}

resource "libvirt_cloudinit_disk" "worker" {
  count          = length(local.worker_vms)
  name           = "${local.worker_vms[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init_user_data.tpl", {
    hostname   = local.worker_vms[count.index].name,
    public_key = var.kube_ssh_public_key
  })
  network_config = templatefile("${path.module}/cloud_init_network_config.tpl", {
    ip      = local.worker_vms[count.index].ip,
    gateway = var.gateway,
    dns     = var.dns
  })
  pool           = "default"
}

# Creates domains (VMs)
resource "libvirt_domain" "lb" {
  count  = length(local.lb_vms)
  name   = local.lb_vms[count.index].name
  memory = local.lb_vms[count.index].memory
  vcpu   = local.lb_vms[count.index].vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.lb[count.index].id

  disk {
    volume_id = libvirt_volume.lb[count.index].id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }
}

resource "libvirt_domain" "cp" {
  count  = length(local.cp_vms)
  name   = local.cp_vms[count.index].name
  memory = local.cp_vms[count.index].memory
  vcpu   = local.cp_vms[count.index].vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.cp[count.index].id

  disk {
    volume_id = libvirt_volume.cp[count.index].id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }
}

resource "libvirt_domain" "worker" {
  count  = length(local.worker_vms)
  name   = local.worker_vms[count.index].name
  memory = local.worker_vms[count.index].memory
  vcpu   = local.worker_vms[count.index].vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.worker[count.index].id

  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }
}

# Inventory & Outputs
data "template_file" "inventory" {
  template = file("${path.module}/inventory.tpl")

  vars = {
    lb1_ip      = local.lb_vms[0].ip
    lb2_ip      = local.lb_vms[1].ip
    cp1_ip      = local.cp_vms[0].ip
    cp2_ip      = local.cp_vms[1].ip
    cp3_ip      = local.cp_vms[2].ip
    worker1_ip  = local.worker_vms[0].ip
    worker2_ip  = local.worker_vms[1].ip
    worker3_ip  = local.worker_vms[2].ip
  }
}

resource "local_file" "inventory" {
  content  = data.template_file.inventory.rendered
  filename = "${path.module}/../ansible/inventory.ini"
}

output "vm_ips" {
  value = merge(
    { for vm in local.lb_vms : vm.name => vm.ip },
    { for vm in local.cp_vms : vm.name => vm.ip },
    { for vm in local.worker_vms : vm.name => vm.ip }
  )
}
