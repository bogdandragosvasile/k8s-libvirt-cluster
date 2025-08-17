#cloud-config
hostname: ${hostname}

users:
  - name: ${default_user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: %{ if distro_family == "debian" }sudo, users%{ else }wheel, users%{ endif }
    shell: /bin/bash
    ssh_authorized_keys:
      - ${public_key}

package_update: true
package_upgrade: true
packages:
%{ if package_mgr == "apt" ~}
  - qemu-guest-agent
  - openssh-server
  - curl
  - wget
  - ca-certificates
%{ elif package_mgr == "dnf" || package_mgr == "yum" ~}
  - qemu-guest-agent
  - openssh-server
  - curl
  - wget
  - ca-certificates
%{ elif package_mgr == "zypper" ~}
  - qemu-guest-agent
  - openssh
  - curl
  - wget
  - ca-certificates
%{ endif ~}

runcmd:
  - systemctl enable --now qemu-guest-agent
%{ if package_mgr == "apt" ~}
  - systemctl enable --now ssh
%{ else ~}
  - systemctl enable --now sshd
%{ endif ~}
  # Ensure SSH is accessible
  - sleep 30
  - systemctl status sshd || systemctl status ssh
