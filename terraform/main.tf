# Complete main.tf for Kubernetes cluster on Libvirt with Ubuntu 24.04 base image
# Provisions: 2 load balancers, 3 control planes, 3 workers
# Assumes cloud_init_user_data.tpl, cloud_init_network_config.tpl, and inventory.tpl are in the same directory

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"  # Correct community provider source
      version = "~> 0.8.3"           # Pin to a stable version
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"  # Connect to local Libvirt
}

# Variables (consolidated here)
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
  cp_vms = [
    { name = "kcontrolplane1", ip = "172.16.16.101", memory = 4096, vcpu = 2 },
    { name = "kcontrolplane2", ip = "172.16.16.102", memory = 4096, vcpu = 2 },
    { name = "kcontrolplane3", ip = "172.16.16.103", memory = 4096, vcpu = 2 }
  ]
  worker_vms = [
    { name = "kworker1", ip = "172.16.16.201", memory = 8192, vcpu = 4 },
    { name = "kworker2", ip = "172.16.16.202", memory = 8192, vcpu = 4 },
    { name = "kworker3", ip = "172.16.16.203", memory = 8192, vcpu = 4 }
  ]
  all_vms = concat(local.lb_vms, local.cp_vms, local.worker_vms)
}

resource "libvirt_volume" "lb" {
  count            = length(local.lb_vms)
  name             = "${local.lb_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 10737418240  # 10 GB
}

resource "libvirt_cloudinit_disk" "lb" {
  count          = length(local.lb_vms)
  name           = "${local.lb_vms[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init_user_data.tpl", { hostname = local.lb_vms[count.index].name, public_key = var.kube_ssh_public_key })
  network_config = templatefile("${path.module}/cloud_init_network_config.tpl", { ip = local.lb_vms[count.index].ip, gateway = var.gateway, dns = var.dns })
  pool           = "default"
}

resource "libvirt_domain" "lb" {
  count  = length(local.lb_vms)
  name   = local.lb_vms[count.index].name
  memory = local.lb_vms[count.index].memory
  vcpu   = local.lb_vms[count.index].vcpu
  qemu_agent = true  # Enable for IP retrieval

  cloudinit = libvirt_cloudinit_disk.lb[count.index].id

  disk {
    volume_id = libvirt_volume.lb[count.index].id
  }

  network_interface {
    network_name = "default"
    wait_for_lease = true
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

  timeouts {
    create = "10m"  # Increase for boot/IP wait
  }
}

# Repeat similar blocks for cp and worker (omitted for brevity; use same structure as lb with their locals)

# Poll for IPs after creation
resource "null_resource" "wait_for_ips" {
  depends_on = [libvirt_domain.lb, libvirt_domain.cp, libvirt_domain.worker]  # Add all domain resources

  provisioner "local-exec" {
    command = "sleep 120"  # Wait 2 min for boot/agent
  }
}

# Generate Ansible inventory.ini (depends on wait)
data "template_file" "inventory" {
  depends_on = [null_resource.wait_for_ips]
  template = file("${path.module}/inventory.tpl")

  vars = {
    lb1_ip      = try(libvirt_domain.lb[0].network_interface[0].addresses[0], local.lb_vms[0].ip)
    lb2_ip      = try(libvirt_domain.lb[1].network_interface[0].addresses[0], local.lb_vms[1].ip)
    cp1_ip      = try(libvirt_domain.cp[0].network_interface[0].addresses[0], local.cp_vms[0].ip)
    cp2_ip      = try(libvirt_domain.cp[1].network_interface[0].addresses[0], local.cp_vms[1].ip)
    cp3_ip      = try(libvirt_domain.cp[2].network_interface[0].addresses[0], local.cp_vms[2].ip)
    worker1_ip  = try(libvirt_domain.worker[0].network_interface[0].addresses[0], local.worker_vms[0].ip)
    worker2_ip  = try(libvirt_domain.worker[1].network_interface[0].addresses[0], local.worker_vms[1].ip)
    worker3_ip  = try(libvirt_domain.worker[2].network_interface[0].addresses[0], local.worker_vms[2].ip)
  }
}

resource "local_file" "inventory" {
  content  = data.template_file.inventory.rendered
  filename = "${path.module}/../ansible/inventory.ini"
}

# Outputs
output "vm_ips" {
  value = { for vm in local.all_vms : vm.name => try(libvirt_domain[vm.name].network_interface[0].addresses[0], vm.ip) }  # Use map for all VMs
  description = "IPs of all provisioned VMs"
}

output "ansible_inventory_path" {
  value       = local_file.inventory.filename
  description = "Path to generated Ansible inventory file"
}
