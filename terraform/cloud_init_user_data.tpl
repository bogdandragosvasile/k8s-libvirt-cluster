#cloud-config

hostname: ${hostname}

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo, users
    shell: /bin/bash
    ssh_authorized_keys:
      - ${public_key}
    lock_passwd: false  # Enable password login for ubuntu
    passwd: $6$l3sIKeAGXzaSeHlN$mIMt1w3.T236Stxf74thp.glTtb/.Vt8p0Yv/jZdzz6C4/blQ./KBiYiWy2rlJMFl0DD9NYMBE4Tee4cyPvs7.  # Your hashed password

apt:
  conf: |
    APT::Periodic::Update-Package-Lists "0";
    APT::Periodic::Unattended-Upgrade "0";

packages:
  - openssh-server  # Explicit install (pre-installed in Ubuntu, but ensures)
  - sudo
  - net-tools
  - ufw

runcmd:
  - systemctl stop unattended-upgrades apt-daily.timer apt-daily-upgrade.timer || true
  - sleep 30  # Delay for network to stabilize
  - sudo apt update -y  # Explicit update
  - echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
  - ufw allow 22 || true
  - systemctl enable --now ssh
  - systemctl restart ssh
