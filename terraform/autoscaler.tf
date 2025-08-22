# Autoscaling Infrastructure Configuration
# This file contains Terraform resources for supporting autoscaling in the Kubernetes cluster

# Create additional worker nodes for autoscaling
locals {
  # Define autoscaling worker node configurations
  autoscaling_worker_vms = [
    { name = "kworker4", ip = "192.168.122.204", memory = 8192, vcpu = 4 },
    { name = "kworker5", ip = "192.168.122.205", memory = 8192, vcpu = 4 },
    { name = "kworker6", ip = "192.168.122.206", memory = 8192, vcpu = 4 },
    { name = "kworker7", ip = "192.168.122.207", memory = 8192, vcpu = 4 },
    { name = "kworker8", ip = "192.168.122.208", memory = 8192, vcpu = 4 },
    { name = "kworker9", ip = "192.168.122.209", memory = 8192, vcpu = 4 },
    { name = "kworker10", ip = "192.168.122.210", memory = 8192, vcpu = 4 }
  ]
}

# Create volumes for autoscaling worker nodes
resource "libvirt_volume" "autoscaling_worker" {
  count            = var.enable_autoscaling ? length(local.autoscaling_worker_vms) : 0
  name             = "${local.autoscaling_worker_vms[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 32212254720  # 30GB
}

# Create cloud-init disks for autoscaling worker nodes
resource "libvirt_cloudinit_disk" "autoscaling_worker" {
  count          = var.enable_autoscaling ? length(local.autoscaling_worker_vms) : 0
  name           = "${local.autoscaling_worker_vms[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init_user_data.tpl", {
    hostname   = local.autoscaling_worker_vms[count.index].name,
    public_key = var.kube_ssh_public_key
  })
  network_config = templatefile("${path.module}/cloud_init_network_config.tpl", {
    ip      = local.autoscaling_worker_vms[count.index].ip,
    gateway = var.gateway,
    dns     = var.dns
  })
  pool           = "default"
}

# Create autoscaling worker domains (VMs) - initially stopped
resource "libvirt_domain" "autoscaling_worker" {
  count  = var.enable_autoscaling ? length(local.autoscaling_worker_vms) : 0
  name   = local.autoscaling_worker_vms[count.index].name
  memory = local.autoscaling_worker_vms[count.index].memory
  vcpu   = local.autoscaling_worker_vms[count.index].vcpu
  qemu_agent = true
  running = false  # Start stopped for autoscaling

  cloudinit = libvirt_cloudinit_disk.autoscaling_worker[count.index].id

  disk {
    volume_id = libvirt_volume.autoscaling_worker[count.index].id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = false  # Don't wait since VM is stopped
  }
}

# Create autoscaling configuration file
resource "local_file" "autoscaling_config" {
  count    = var.enable_autoscaling ? 1 : 0
  content  = templatefile("${path.module}/autoscaling-config.tpl", {
    worker_nodes = local.autoscaling_worker_vms
    cluster_name = var.cluster_name
  })
  filename = "${path.module}/../scripts/autoscaling-config.yaml"
}

# Output autoscaling worker information
output "autoscaling_workers" {
  value = var.enable_autoscaling ? {
    for i, vm in local.autoscaling_worker_vms : vm.name => {
      ip      = vm.ip
      memory  = vm.memory
      vcpu    = vm.vcpu
      status  = "stopped"
    }
  } : {}
  description = "Autoscaling worker node configurations"
}
