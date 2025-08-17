#!/bin/bash

# =============================================================================
# Automated Prerequisites Installation for k8s-libvirt-cluster
# =============================================================================
# This script automates the installation of all required tools on a clean
# Linux system to deploy the Kubernetes cluster.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# =============================================================================
# System Detection
# =============================================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        CODENAME=${VERSION_CODENAME:-}
    else
        error "Cannot detect operating system"
    fi
    
    log "Detected OS: $OS $VERSION"
}

detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PKG_MGR="apt"
        PKG_UPDATE="apt-get update"
        PKG_INSTALL="apt-get install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
        PKG_UPDATE="dnf check-update || true"
        PKG_INSTALL="dnf install -y"
    elif command -v yum &> /dev/null; then
        PKG_MGR="yum"
        PKG_UPDATE="yum check-update || true"
        PKG_INSTALL="yum install -y"
    elif command -v zypper &> /dev/null; then
        PKG_MGR="zypper"
        PKG_UPDATE="zypper refresh"
        PKG_INSTALL="zypper install -y"
    else
        error "No supported package manager found"
    fi
    
    log "Package manager: $PKG_MGR"
}

# =============================================================================
# Prerequisites Installation Functions
# =============================================================================

install_basic_packages() {
    log "Installing basic packages..."
    
    case $PKG_MGR in
        apt)
            $PKG_UPDATE
            $PKG_INSTALL curl wget git jq unzip software-properties-common \
                        ca-certificates gnupg lsb-release
            ;;
        dnf|yum)
            $PKG_UPDATE
            $PKG_INSTALL curl wget git jq unzip ca-certificates gnupg \
                        dnf-plugins-core || \
            $PKG_INSTALL curl wget git jq unzip ca-certificates gnupg
            ;;
        zypper)
            $PKG_UPDATE
            $PKG_INSTALL curl wget git jq unzip ca-certificates
            ;;
    esac
    
    success "Basic packages installed"
}

install_virtualization() {
    log "Installing KVM/libvirt virtualization stack..."
    
    case $PKG_MGR in
        apt)
            $PKG_INSTALL qemu-kvm libvirt-daemon-system libvirt-clients \
                        bridge-utils virt-manager cpu-checker
            ;;
        dnf)
            $PKG_INSTALL qemu-kvm libvirt virt-manager bridge-utils \
                        virt-install libguestfs-tools
            ;;
        yum)
            $PKG_INSTALL qemu-kvm libvirt libvirt-python libguestfs-tools \
                        virt-install bridge-utils
            ;;
        zypper)
            $PKG_INSTALL qemu-kvm libvirt bridge-utils virt-manager \
                        libguestfs
            ;;
    esac
    
    # Enable and start libvirt
    systemctl enable libvirtd
    systemctl start libvirtd
    
    # Add user to libvirt group
    usermod -aG libvirt $SUDO_USER || usermod -aG libvirt $USER
    
    success "Virtualization stack installed"
}

install_docker() {
    log "Installing Docker..."
    
    case $PKG_MGR in
        apt)
            # Remove old versions
            apt-get remove -y docker docker-engine docker.io containerd runc || true
            
            # Add Docker repository
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            $PKG_UPDATE
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        dnf)
            # Remove old versions
            dnf remove -y docker docker-client docker-client-latest docker-common \
                         docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
            
            # Add Docker repository
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || \
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        yum)
            # Remove old versions
            yum remove -y docker docker-client docker-client-latest docker-common \
                         docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
            
            # Add Docker repository
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        zypper)
            zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo
            zypper refresh
            $PKG_INSTALL docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
    esac
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    # Add user to docker group
    usermod -aG docker $SUDO_USER || usermod -aG docker $USER
    
    success "Docker installed"
}

install_terraform() {
    log "Installing Terraform..."
    
    case $PKG_MGR in
        apt)
            curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
            $PKG_UPDATE
            $PKG_INSTALL terraform
            ;;
        dnf|yum)
            $PKG_INSTALL dnf-plugins-core || $PKG_INSTALL yum-utils
            dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo || \
            yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            $PKG_INSTALL terraform
            ;;
        zypper)
            zypper addrepo --gpgcheck-allow-unsigned-repo --refresh https://rpm.releases.hashicorp.com/SUSE/hashicorp.repo
            $PKG_INSTALL terraform
            ;;
    esac
    
    success "Terraform installed"
}

install_ansible() {
    log "Installing Ansible..."
    
    case $PKG_MGR in
        apt)
            # Use official PPA for latest version
            add-apt-repository --yes --update ppa:ansible/ansible
            $PKG_INSTALL ansible
            ;;
        dnf)
            $PKG_INSTALL ansible
            ;;
        yum)
            # Enable EPEL repository first
            $PKG_INSTALL epel-release
            $PKG_INSTALL ansible
            ;;
        zypper)
            $PKG_INSTALL ansible
            ;;
    esac
    
    success "Ansible installed"
}

install_jenkins() {
    log "Installing Jenkins..."
    
    case $PKG_MGR in
        apt)
            # Install Java
            $PKG_INSTALL openjdk-17-jdk
            
            # Add Jenkins repository
            curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
            echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
            
            $PKG_UPDATE
            $PKG_INSTALL jenkins
            ;;
        dnf|yum)
            # Install Java
            $PKG_INSTALL java-17-openjdk java-17-openjdk-devel
            
            # Add Jenkins repository
            curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg
            echo -e "[jenkins]\nname=Jenkins-stable\nbaseurl=https://pkg.jenkins.io/redhat-stable\ngpgcheck=1\ngpgkey=file:///usr/share/keyrings/jenkins-keyring.gpg" > /etc/yum.repos.d/jenkins.repo
            
            $PKG_INSTALL jenkins
            ;;
        zypper)
            # Install Java
            $PKG_INSTALL java-17-openjdk java-17-openjdk-devel
            
            # Add Jenkins repository
            zypper addrepo -f https://pkg.jenkins.io/opensuse-stable/ jenkins
            $PKG_INSTALL jenkins
            ;;
    esac
    
    # Enable and start Jenkins
    systemctl enable jenkins
    systemctl start jenkins
    
    # Add jenkins user to required groups
    usermod -aG docker jenkins
    usermod -aG libvirt jenkins
    
    success "Jenkins installed"
}

install_kubectl() {
    log "Installing kubectl..."
    
    # Download the latest kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    success "kubectl installed"
}

# =============================================================================
# Network Configuration
# =============================================================================

configure_bridge_network() {
    log "Configuring bridge network (optional)..."
    
    case $PKG_MGR in
        apt)
            $PKG_INSTALL bridge-utils
            ;;
        dnf|yum)
            $PKG_INSTALL bridge-utils
            ;;
        zypper)
            $PKG_INSTALL bridge-utils
            ;;
    esac
    
    # Create a sample bridge configuration
    cat > /etc/systemd/network/br0.netdev << EOF
[NetDev]
Name=br0
Kind=bridge
EOF
    
    cat > /etc/systemd/network/br0.network << EOF
[Match]
Name=br0

[Network]
DHCP=yes
IPForward=yes
EOF
    
    warn "Bridge network configuration created. You may need to manually configure your network interfaces."
    warn "Restart systemd-networkd after configuring: systemctl restart systemd-networkd"
}

# =============================================================================
# Verification Functions
# =============================================================================

verify_installation() {
    log "Verifying installation..."
    
    local failed=0
    
    # Check KVM support
    if ! kvm-ok >/dev/null 2>&1 && ! grep -E "(vmx|svm)" /proc/cpuinfo >/dev/null; then
        warn "KVM hardware acceleration not available"
        ((failed++))
    fi
    
    # Check services
    local services=("libvirtd" "docker" "jenkins")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet $service; then
            warn "Service $service is not running"
            ((failed++))
        fi
    done
    
    # Check commands
    local commands=("virsh" "docker" "terraform" "ansible" "kubectl")
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd >/dev/null 2>&1; then
            error "Command $cmd not found"
            ((failed++))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        success "All prerequisites installed and verified successfully!"
    else
        warn "$failed issues found. Please review and fix manually."
    fi
}

show_post_install_info() {
    log "Post-installation information:"
    echo
    echo -e "${GREEN}=== Jenkins Access ===${NC}"
    echo "Jenkins URL: http://localhost:8080"
    echo "Initial admin password:"
    cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Password file not found. Jenkins may still be starting."
    echo
    echo -e "${GREEN}=== Required Manual Steps ===${NC}"
    echo "1. Log out and log back in to apply group memberships"
    echo "2. Configure Jenkins with required plugins and credentials"
    echo "3. Generate SSH keys for cluster access:"
    echo "   ssh-keygen -t ed25519 -f ~/.ssh/k8s-cluster -N \"\""
    echo "4. Configure bridge network if using bridge mode"
    echo
    echo -e "${GREEN}=== Next Steps ===${NC}"
    echo "1. Clone the k8s-libvirt-cluster repository"
    echo "2. Configure Jenkins pipeline with your repository"
    echo "3. Run the deployment pipeline with your preferred settings"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log "Starting automated prerequisites installation..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Store original user
    if [ -z "${SUDO_USER:-}" ]; then
        warn "SUDO_USER not set. Some group assignments may not work correctly."
    fi
    
    # Detect system
    detect_os
    detect_package_manager
    
    # Install components
    install_basic_packages
    install_virtualization
    install_docker
    install_terraform
    install_ansible
    install_jenkins
    install_kubectl
    
    # Optional configurations
    read -p "Configure bridge network? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        configure_bridge_network
    fi
    
    # Verify installation
    verify_installation
    
    # Show post-install info
    show_post_install_info
    
    success "Prerequisites installation completed!"
}

# Run main function
main "$@"
