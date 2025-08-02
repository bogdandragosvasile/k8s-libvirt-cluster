terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_network" "k8s_network" {
  name      = "k8s_net"
  mode      = "nat"
  addresses = ["172.16.16.0/24"]
  autostart = true
}

resource "libvirt_volume" "debian-bookworm-base" {
  name   = "debian-bookworm-base.qcow2"
  pool   = "default"
  source = "https://cloud.debian.org/images/cloud/bookworm/20231204-1573/debian-12-genericcloud-amd64.qcow2"
  format = "qcow2"
}

locals {
  vms = [
    { name = "loadbalancer1", role = "Load Balancer", ip = "172.16.16.51",  ram = 512,  vcpus = 1 },
    { name = "loadbalancer2", role = "Load Balancer", ip = "172.16.16.52",  ram = 512,  vcpus = 1 },
    { name = "kcontrolplane1", role = "Control Plane", ip = "172.16.16.101", ram = 2048, vcpus = 2 },
    { name = "kcontrolplane2", role = "Control Plane", ip = "172.16.16.102", ram = 2048, vcpus = 2 },
    { name = "kcontrolplane3", role = "Control Plane", ip = "172.16.16.103", ram = 2048, vcpus = 2 },
    { name = "kworker1",      role = "Worker",         ip = "172.16.16.201", ram = 2048, vcpus = 2 },
    { name = "kworker2",      role = "Worker",         ip = "172.16.16.202", ram = 2048, vcpus = 2 },
    { name = "kworker3",      role = "Worker",         ip = "172.16.16.203", ram = 2048, vcpus = 2 }
  ]
}

resource "libvirt_volume" "vms" {
  for_each        = { for vm in local.vms: vm.name => vm }
  name            = "${each.key}.qcow2"
  pool            = "default"
  base_volume_id  = libvirt_volume.debian-bookworm-base.id
  format          = "qcow2"
}

resource "libvirt_domain" "vms" {
  for_each = { for vm in local.vms: vm.name => vm }
  name     = each.key
  memory   = each.value.ram
  vcpu     = each.value.vcpus

  network_interface {
    network_id = libvirt_network.k8s_network.id
    addresses  = [each.value.ip]
  }

  disk {
    volume_id = libvirt_volume.vms[each.key].id
  }

  cloudinit = libvirt_cloudinit_disk.ci[each.key].id
}

resource "libvirt_cloudinit_disk" "ci" {
  for_each = { for vm in local.vms: vm.name => vm }
  name           = "${each.key}-cloudinit.iso"
  pool           = "default"
  user_data      = data.template_file.user_data[each.key].rendered
  network_config = data.template_file.network_config[each.key].rendered
}

data "template_file" "user_data" {
  for_each = { for vm in local.vms: vm.name => vm }
  template = file("${path.module}/cloud_init_user_data.tpl")
  vars = {
    hostname   = each.key
    public_key = var.kube_ssh_public_key
  }
}

data "template_file" "network_config" {
  for_each = { for vm in local.vms: vm.name => vm }
  template = file("${path.module}/cloud_init_network_config.tpl")
  vars = {
    ip      = each.value.ip
    gateway = "172.16.16.1"
    dns     = "8.8.8.8"
  }
}

locals {
  load_balancers = [for vm in local.vms : { name = vm.name, ip = vm.ip } if vm.role == "Load Balancer"]
  control_planes = [for vm in local.vms : { name = vm.name, ip = vm.ip } if vm.role == "Control Plane"]
  workers        = [for vm in local.vms : { name = vm.name, ip = vm.ip } if vm.role == "Worker"]
}

resource "local_file" "ansible_inventory" {
  content  = templatefile("${path.module}/inventory.tmpl", {
    load_balancers = local.load_balancers
    control_planes = local.control_planes
    workers        = local.workers
  })
  filename = "${path.module}/../ansible/inventory.ini"
}
