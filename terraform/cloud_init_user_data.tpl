#cloud-config
hostname: ${hostname}

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo, users
    shell: /bin/bash
    ssh_authorized_keys:
      - ${public_key}

package_update: true
package_upgrade: true
packages:
  - qemu-guest-agent
  - openssh-server

runcmd:
  - systemctl enable --now qemu-guest-agent
  - systemctl enable --now ssh
