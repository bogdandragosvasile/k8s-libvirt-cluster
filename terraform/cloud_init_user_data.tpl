#cloud-config

hostname: ${hostname}

users:
  - name: debian
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo, users
    shell: /bin/bash
    ssh_authorized_keys:
      - ${public_key}
    lock_passwd: false  # Enable password login
    passwd: $6$l3sIKeAGXzaSeHlN$mIMt1w3.T236Stxf74thp.glTtb/.Vt8p0Yv/jZdzz6C4/blQ./KBiYiWy2rlJMFl0DD9NYMBE4Tee4cyPvs7.  # Your hashed password

apt:
  conf: |
    APT::Periodic::Update-Package-Lists "0";
    APT::Periodic::Unattended-Upgrade "0";

runcmd:
  - systemctl stop unattended-upgrades apt-daily.timer apt-daily-upgrade.timer || true
  - apt update -y
  - apt install -y sudo openssh-server net-tools ufw
  - echo "debian ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
  - ufw allow 22 || true
  - systemctl enable --now ssh
  - systemctl restart ssh
  - ip link set dev lo up  # Ensure loopback is up
  - sleep 10  # Brief wait for network to stabilize
  - systemctl restart ssh  # Restart again after network
