#!/bin/bash

# System Update and Basic Packages Installation
# Part of K8s Libvirt Cluster Prerequisites
# Version: 1.1.1

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Update package lists
log_info "Updating package lists..."
apt update

# Upgrade existing packages
log_info "Upgrading existing packages..."
DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install essential packages
log_info "Installing essential packages..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    net-tools \
    dnsutils \
    iputils-ping \
    traceroute \
    nmap \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    pkg-config \
    libssl-dev \
    libffi-dev \
    python3-dev \
    ssh \
    openssh-server \
    openssh-client \
    rsync \
    sudo \
    acl \
    attr \
    autoconf \
    automake \
    bc \
    bison \
    build-essential \
    bzip2 \
    cmake \
    cpio \
    cpp \
    debhelper \
    dh-python \
    diffutils \
    dkms \
    dpkg-dev \
    fakeroot \
    flex \
    g++ \
    gawk \
    gcc \
    gettext \
    intltool-debian \
    libasprintf-dev \
    libc6-dev \
    libc-dev-bin \
    libcroco3 \
    libdb-dev \
    libexpat1-dev \
    libgcc-13-dev \
    libgdbm-compat4 \
    libgdbm-dev \
    libglib2.0-dev \
    libgomp1 \
    libisl23 \
    libitm1 \
    libmpc3 \
    libmpfr6 \
    libnsl-dev \
    libpcre3-dev \
    libpython3-dev \
    libquadmath0 \
    libreadline-dev \
    libsqlite3-dev \
    libstdc++-13-dev \
    libtirpc-dev \
    libtool \
    libubsan1 \
    linux-libc-dev \
    m4 \
    make \
    patch \
    pkg-config \
    python3-dev \
    python3-setuptools \
    python3-wheel \
    quilt \
    xz-utils \
    zlib1g-dev

# Install additional useful tools
log_info "Installing additional useful tools..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    tmux \
    screen \
    mc \
    ncdu \
    iotop \
    iftop \
    nethogs \
    tcpdump \
    wireshark-qt \
    fail2ban \
    logwatch \
    rkhunter \
    chkrootkit \
    clamav \
    clamav-daemon \
    clamav-freshclam \
    apparmor \
    apparmor-utils \
    auditd \
    audispd-plugins

# Configure SSH
log_info "Configuring SSH..."
if [[ ! -f /etc/ssh/sshd_config.backup ]]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
fi

# Generate SSH keys if they don't exist
if [[ ! -f /root/.ssh/id_ed25519 ]]; then
    log_info "Generating SSH keys..."
    mkdir -p /root/.ssh
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -C "k8s-libvirt-cluster"
    chmod 600 /root/.ssh/id_ed25519
    chmod 644 /root/.ssh/id_ed25519.pub
fi

# Configure firewall
log_info "Configuring firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 8080/tcp  # Jenkins
ufw allow 6443/tcp  # Kubernetes API
ufw allow 2379/tcp  # etcd
ufw allow 2380/tcp  # etcd
ufw allow 10250/tcp # kubelet
ufw allow 10251/tcp # kube-scheduler
ufw allow 10252/tcp # kube-controller-manager
ufw allow 10255/tcp # kubelet read-only
ufw allow 30000:32767/tcp  # NodePort services

# Configure system limits
log_info "Configuring system limits..."
cat >> /etc/security/limits.conf << EOF

# K8s Libvirt Cluster limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Configure sysctl parameters
log_info "Configuring sysctl parameters..."
cat >> /etc/sysctl.conf << EOF

# K8s Libvirt Cluster sysctl settings
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.tcp_max_syn_backlog = 40000
net.core.somaxconn = 40000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_mem = 786432 1048576 1572864
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

# Apply sysctl changes
sysctl -p

# Configure timezone
log_info "Configuring timezone..."
timedatectl set-timezone UTC

# Configure NTP
log_info "Configuring NTP..."
DEBIAN_FRONTEND=noninteractive apt install -y ntp
systemctl enable ntp
systemctl start ntp

# Configure log rotation
log_info "Configuring log rotation..."
cat > /etc/logrotate.d/k8s-libvirt << EOF
/var/log/k8s-libvirt/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF

# Create log directory
mkdir -p /var/log/k8s-libvirt

# Configure systemd journal
log_info "Configuring systemd journal..."
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-k8s-libvirt.conf << EOF
[Journal]
SystemMaxUse=1G
SystemKeepFree=1G
SystemMaxFileSize=100M
MaxRetentionSec=30day
EOF

# Restart systemd-journald
systemctl restart systemd-journald

# Configure automatic security updates
log_info "Configuring automatic security updates..."
DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

# Enable unattended upgrades
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# Configure fail2ban
log_info "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Create basic fail2ban configuration
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[jenkins]
enabled = true
port = 8080
filter = jenkins
logpath = /var/log/jenkins/jenkins.log
maxretry = 5
EOF

# Restart fail2ban
systemctl restart fail2ban

# Configure monitoring
log_info "Configuring basic monitoring..."
cat > /etc/cron.d/k8s-libvirt-monitoring << EOF
# K8s Libvirt Cluster monitoring
*/5 * * * * root /usr/bin/df -h | grep -E '^/dev/' | awk '\$5 > "80%" {print "WARNING: Disk usage high on " \$1 " - " \$5}' | logger -t k8s-libvirt-monitoring
*/5 * * * * root /usr/bin/free -m | awk 'NR==2{if(\$3/\$2*100 > 80) print "WARNING: Memory usage high - " \$3/\$2*100 "%"}' | logger -t k8s-libvirt-monitoring
*/5 * * * * root /usr/bin/uptime | awk '{if(\$10 > 5) print "WARNING: High load average - " \$10}' | logger -t k8s-libvirt-monitoring
EOF

# Set proper permissions
chmod 644 /etc/cron.d/k8s-libvirt-monitoring

# Create system information script
log_info "Creating system information script..."
cat > /usr/local/bin/system-info << 'EOF'
#!/bin/bash
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $4}') available"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "=== Network ==="
ip addr show | grep -E '^[0-9]+:|inet ' | grep -v '127.0.0.1'
echo "=== Services ==="
systemctl is-active libvirtd jenkins docker ssh fail2ban
echo "=== Virtualization ==="
virsh list --all 2>/dev/null || echo "Libvirt not available"
echo "=== Docker ==="
docker --version 2>/dev/null || echo "Docker not available"
echo "=== Kubernetes Tools ==="
kubectl version --client 2>/dev/null || echo "kubectl not available"
terraform version 2>/dev/null || echo "Terraform not available"
helm version 2>/dev/null || echo "Helm not available"
EOF

chmod +x /usr/local/bin/system-info

log_success "System update and basic packages installation completed!"
log_info "System has been updated and configured with essential packages and security settings."



