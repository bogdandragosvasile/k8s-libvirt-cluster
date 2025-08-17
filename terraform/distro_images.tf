# =============================================================================
# Linux Distribution Image Configuration
# =============================================================================

locals {
  # Distribution image configurations
  distro_configs = {
    # Ubuntu Distributions
    "ubuntu-24.04" = {
      name         = "ubuntu-24.04-server-cloudimg-amd64"
      source_url   = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      user         = "ubuntu"
      package_mgr  = "apt"
      init_system  = "systemd"
      family       = "debian"
    }
    "ubuntu-22.04" = {
      name         = "ubuntu-22.04-server-cloudimg-amd64"
      source_url   = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      user         = "ubuntu"
      package_mgr  = "apt"
      init_system  = "systemd"
      family       = "debian"
    }
    "ubuntu-20.04" = {
      name         = "ubuntu-20.04-server-cloudimg-amd64"
      source_url   = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
      user         = "ubuntu"
      package_mgr  = "apt"
      init_system  = "systemd"
      family       = "debian"
    }
    
    # CentOS Distributions
    "centos-9" = {
      name         = "centos-9-stream-cloudimg-amd64"
      source_url   = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
      user         = "centos"
      package_mgr  = "dnf"
      init_system  = "systemd"
      family       = "rhel"
    }
    "centos-8" = {
      name         = "centos-8-stream-cloudimg-amd64"
      source_url   = "https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
      user         = "centos"
      package_mgr  = "dnf"
      init_system  = "systemd"
      family       = "rhel"
    }
    
    # Rocky Linux Distributions
    "rocky-9" = {
      name         = "rocky-9-cloudimg-amd64"
      source_url   = "https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
      user         = "rocky"
      package_mgr  = "dnf"
      init_system  = "systemd"
      family       = "rhel"
    }
    "rocky-8" = {
      name         = "rocky-8-cloudimg-amd64"
      source_url   = "https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2"
      user         = "rocky"
      package_mgr  = "dnf"
      init_system  = "systemd"
      family       = "rhel"
    }
    
    # Debian Distributions
    "debian-12" = {
      name         = "debian-12-cloudimg-amd64"
      source_url   = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
      user         = "debian"
      package_mgr  = "apt"
      init_system  = "systemd"
      family       = "debian"
    }
    "debian-11" = {
      name         = "debian-11-cloudimg-amd64"
      source_url   = "https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
      user         = "debian"
      package_mgr  = "apt"
      init_system  = "systemd"
      family       = "debian"
    }
    
    # openSUSE Distributions
    "opensuse-15.5" = {
      name         = "opensuse-leap-15.5-cloudimg-amd64"
      source_url   = "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5-OpenStack.x86_64.qcow2"
      user         = "opensuse"
      package_mgr  = "zypper"
      init_system  = "systemd"
      family       = "suse"
    }
    "opensuse-15.4" = {
      name         = "opensuse-leap-15.4-cloudimg-amd64"
      source_url   = "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4-OpenStack.x86_64.qcow2"
      user         = "opensuse"
      package_mgr  = "zypper"
      init_system  = "systemd"
      family       = "suse"
    }
  }
  
  # Selected distribution configuration
  selected_distro = local.distro_configs[var.linux_distro]
  
  # Network configuration based on mode
  network_config = var.network_mode == "bridge" ? {
    mode           = "bridge"
    bridge_name    = var.bridge_interface
    network_cidr   = var.bridge_network_cidr
    gateway        = cidrhost(var.bridge_network_cidr, 1)
    dns_servers    = ["8.8.8.8", "8.8.4.4"]
    metallb_range  = var.metallb_ip_range != "" ? var.metallb_ip_range : "${cidrhost(var.bridge_network_cidr, 240)}-${cidrhost(var.bridge_network_cidr, 250)}"
  } : {
    mode           = "nat"
    bridge_name    = "default"
    network_cidr   = var.nat_network_cidr
    gateway        = cidrhost(var.nat_network_cidr, 1)
    dns_servers    = ["8.8.8.8", "8.8.4.4"]
    metallb_range  = var.metallb_ip_range != "" ? var.metallb_ip_range : "${cidrhost(var.nat_network_cidr, 240)}-${cidrhost(var.nat_network_cidr, 250)}"
  }
  
  # VM IP addresses based on network mode
  vm_ips = var.network_mode == "bridge" ? {
    # Bridge mode - use host network range
    lb_vms = [
      { name = "loadbalancer1", ip = cidrhost(var.bridge_network_cidr, 51), memory = var.lb_memory_mb, vcpu = var.lb_cpu_cores },
      { name = "loadbalancer2", ip = cidrhost(var.bridge_network_cidr, 52), memory = var.lb_memory_mb, vcpu = var.lb_cpu_cores }
    ]
    cp_vms = [
      { name = "kcontrolplane1", ip = cidrhost(var.bridge_network_cidr, 101), memory = var.cp_memory_mb, vcpu = var.cp_cpu_cores },
      { name = "kcontrolplane2", ip = cidrhost(var.bridge_network_cidr, 102), memory = var.cp_memory_mb, vcpu = var.cp_cpu_cores },
      { name = "kcontrolplane3", ip = cidrhost(var.bridge_network_cidr, 103), memory = var.cp_memory_mb, vcpu = var.cp_cpu_cores }
    ]
    worker_vms = [
      { name = "kworker1", ip = cidrhost(var.bridge_network_cidr, 201), memory = var.worker_memory_mb, vcpu = var.worker_cpu_cores },
      { name = "kworker2", ip = cidrhost(var.bridge_network_cidr, 202), memory = var.worker_memory_mb, vcpu = var.worker_cpu_cores },
      { name = "kworker3", ip = cidrhost(var.bridge_network_cidr, 203), memory = var.worker_memory_mb, vcpu = var.worker_cpu_cores }
    ]
    virtual_ip = cidrhost(var.bridge_network_cidr, 100)
  } : {
    # NAT mode - use existing scheme
    lb_vms = [
      { name = "loadbalancer1", ip = "192.168.122.51", memory = var.lb_memory_mb, vcpu = var.lb_cpu_cores },
      { name = "loadbalancer2", ip = "192.168.122.52", memory = var.lb_memory_mb, vcpu = var.lb_cpu_cores }
    ]
    cp_vms = [
      { name = "kcontrolplane1", ip = "192.168.122.101", memory = var.cp_memory_mb, vcpu = var.cp_cpu_cores },
      { name = "kcontrolplane2", ip = "192.168.122.102", memory = var.cp_memory_mb, vcpu = var.cp_cpu_cores },
      { name = "kcontrolplane3", ip = "192.168.122.103", memory = var.cp_memory_mb, vcpu = var.cp_cpu_cores }
    ]
    worker_vms = [
      { name = "kworker1", ip = "192.168.122.201", memory = var.worker_memory_mb, vcpu = var.worker_cpu_cores },
      { name = "kworker2", ip = "192.168.122.202", memory = var.worker_memory_mb, vcpu = var.worker_cpu_cores },
      { name = "kworker3", ip = "192.168.122.203", memory = var.worker_memory_mb, vcpu = var.worker_cpu_cores }
    ]
    virtual_ip = "192.168.122.100"
  }
}
