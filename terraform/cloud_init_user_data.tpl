#cloud-config

hostname: ${hostname}

users:
  - name: debian
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo, users
    shell: /bin/bash
    ssh_authorized_keys:
      - ${public_key}

apt:
  conf: |
    APT::Periodic::Update-Package-Lists "0";
    APT::Periodic::Unattended-Upgrade "0";

runcmd:
  - systemctl stop unattended-upgrades apt-daily.timer apt-daily-upgrade.timer || true
  - apt update -y
  - apt install -y sudo openssh-server
  - echo "debian ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
