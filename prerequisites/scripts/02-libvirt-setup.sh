#!/bin/bash

# Libvirt Setup Script for K8s Libvirt Cluster
# Version: 1.0.0
# Description: Installs and configures libvirt, QEMU, and KVM virtualization

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check virtualization support
check_virtualization() {
    log_step "Checking virtualization support..."
    
    # Check CPU virtualization
    if ! egrep -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        log_error "Hardware virtualization (VT-x/AMD-V) is not available or not enabled in BIOS"
        exit 1
    fi
    
    # Check if KVM module is loaded
    if ! lsmod | grep -q kvm; then
        log_info "Loading KVM module..."
        modprobe kvm
        modprobe kvm_intel 2>/dev/null || modprobe kvm_amd 2>/dev/null || true
    fi
    
    log_success "Virtualization support verified"
}

# Install libvirt packages
install_libvirt_packages() {
    log_step "Installing libvirt packages..."
    
    # Update package list
    apt update
    
    # Install libvirt and related packages
    DEBIAN_FRONTEND=noninteractive apt install -y \
        qemu-kvm \
        qemu-system-x86 \
        qemu-system-arm \
        qemu-utils \
        libvirt-daemon-system \
        libvirt-clients \
        bridge-utils \
        virtinst \
        virt-manager \
        libguestfs-tools \
        libvirt-dev \
        python3-libvirt \
        ovmf \
        seabios \
        ipxe-qemu \
        qemu-efi \
        qemu-efi-aarch64 \
        swtpm \
        swtpm-tools \
        libvirt-daemon-driver-storage-gluster \
        libvirt-daemon-driver-storage-iscsi \
        libvirt-daemon-driver-storage-mpath \
        libvirt-daemon-driver-storage-rbd \
        libvirt-daemon-driver-storage-scsi \
        libvirt-daemon-driver-storage-sheepdog \
        libvirt-daemon-driver-storage-zfs \
        libvirt-daemon-driver-storage-core \
        libvirt-daemon-driver-storage-disk \
        libvirt-daemon-driver-storage-file \
        libvirt-daemon-driver-storage-logical \
        libvirt-daemon-driver-storage-mpath \
        libvirt-daemon-driver-storage-scsi \
        libvirt-daemon-driver-storage-iscsi \
        libvirt-daemon-driver-storage-iscsi-direct \
        libvirt-daemon-driver-storage-gluster \
        libvirt-daemon-driver-storage-rbd \
        libvirt-daemon-driver-storage-sheepdog \
        libvirt-daemon-driver-storage-zfs \
        libvirt-daemon-driver-storage-vstorage \
        libvirt-daemon-driver-storage-vbox \
        libvirt-daemon-driver-storage-vmware \
        libvirt-daemon-driver-storage-xen \
        libvirt-daemon-driver-storage-phyp \
        libvirt-daemon-driver-storage-iscsi \
        libvirt-daemon-driver-storage-iscsi-direct \
        libvirt-daemon-driver-storage-gluster \
        libvirt-daemon-driver-storage-rbd \
        libvirt-daemon-driver-storage-sheepdog \
        libvirt-daemon-driver-storage-zfs \
        libvirt-daemon-driver-storage-vstorage \
        libvirt-daemon-driver-storage-vbox \
        libvirt-daemon-driver-storage-vmware \
        libvirt-daemon-driver-storage-xen \
        libvirt-daemon-driver-storage-phyp
    
    log_success "Libvirt packages installed"
}

# Configure libvirt
configure_libvirt() {
    log_step "Configuring libvirt..."
    
    # Start and enable libvirt daemon
    systemctl enable libvirtd
    systemctl start libvirtd
    
    # Add current user to libvirt group
    usermod -a -G libvirt $SUDO_USER
    
    # Configure libvirt daemon
    cat > /etc/libvirt/libvirtd.conf << 'EOF'
# Libvirt daemon configuration
listen_tls = 0
listen_tcp = 1
tcp_port = "16509"
listen_addr = "0.0.0.0"
auth_tcp = "none"
EOF

    # Configure qemu
    cat > /etc/libvirt/qemu.conf << 'EOF'
# QEMU configuration
user = "root"
group = "root"
clear_emulator_capabilities = 0
EOF

    # Restart libvirt daemon
    systemctl restart libvirtd
    
    log_success "Libvirt configured"
}

# Create default network
create_default_network() {
    log_step "Creating default network..."
    
    # Create default network configuration
    cat > /tmp/default-network.xml << 'EOF'
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF

    # Define and start the network
    virsh net-define /tmp/default-network.xml
    virsh net-start default
    virsh net-autostart default
    
    # Clean up
    rm -f /tmp/default-network.xml
    
    log_success "Default network created"
}

# Configure storage pools
configure_storage_pools() {
    log_step "Configuring storage pools..."
    
    # Create default directory pool
    virsh pool-define-as --name default --type dir --target /var/lib/libvirt/images
    virsh pool-start default
    virsh pool-autostart default
    
    # Create ISO pool for installation media
    mkdir -p /var/lib/libvirt/isos
    virsh pool-define-as --name isos --type dir --target /var/lib/libvirt/isos
    virsh pool-start isos
    virsh pool-autostart isos
    
    log_success "Storage pools configured"
}

# Configure firewall for libvirt
configure_firewall() {
    log_step "Configuring firewall for libvirt..."
    
    # Allow libvirt traffic
    ufw allow 16509/tcp  # libvirt TCP
    ufw allow 5900:5999/tcp  # VNC ports
    ufw allow 16514/tcp  # libvirt TLS
    
    log_success "Firewall configured for libvirt"
}

# Create helper scripts
create_helper_scripts() {
    log_step "Creating helper scripts..."
    
    # Create VM management script
    cat > /usr/local/bin/vm-manager << 'EOF'
#!/bin/bash

# VM Management Helper Script
# Usage: vm-manager [start|stop|list|info] [vm-name]

case "$1" in
    start)
        if [[ -z "$2" ]]; then
            echo "Usage: vm-manager start <vm-name>"
            exit 1
        fi
        virsh start "$2"
        ;;
    stop)
        if [[ -z "$2" ]]; then
            echo "Usage: vm-manager stop <vm-name>"
            exit 1
        fi
        virsh shutdown "$2"
        ;;
    list)
        virsh list --all
        ;;
    info)
        if [[ -z "$2" ]]; then
            echo "Usage: vm-manager info <vm-name>"
            exit 1
        fi
        virsh dominfo "$2"
        ;;
    *)
        echo "Usage: vm-manager [start|stop|list|info] [vm-name]"
        echo "Commands:"
        echo "  start <vm-name>  - Start a VM"
        echo "  stop <vm-name>   - Stop a VM"
        echo "  list            - List all VMs"
        echo "  info <vm-name>  - Show VM information"
        ;;
esac
EOF

    chmod +x /usr/local/bin/vm-manager
    
    # Create network management script
    cat > /usr/local/bin/network-manager << 'EOF'
#!/bin/bash

# Network Management Helper Script
# Usage: network-manager [list|info|start|stop] [network-name]

case "$1" in
    list)
        virsh net-list --all
        ;;
    info)
        if [[ -z "$2" ]]; then
            echo "Usage: network-manager info <network-name>"
            exit 1
        fi
        virsh net-info "$2"
        ;;
    start)
        if [[ -z "$2" ]]; then
            echo "Usage: network-manager start <network-name>"
            exit 1
        fi
        virsh net-start "$2"
        ;;
    stop)
        if [[ -z "$2" ]]; then
            echo "Usage: network-manager stop <network-name>"
            exit 1
        fi
        virsh net-destroy "$2"
        ;;
    *)
        echo "Usage: network-manager [list|info|start|stop] [network-name]"
        echo "Commands:"
        echo "  list            - List all networks"
        echo "  info <name>     - Show network information"
        echo "  start <name>    - Start a network"
        echo "  stop <name>     - Stop a network"
        ;;
esac
EOF

    chmod +x /usr/local/bin/network-manager
    
    log_success "Helper scripts created"
}

# Test libvirt installation
test_libvirt() {
    log_step "Testing libvirt installation..."
    
    # Test virsh connection
    if ! virsh list --all > /dev/null 2>&1; then
        log_error "virsh connection test failed"
        return 1
    fi
    
    # Test network listing
    if ! virsh net-list --all > /dev/null 2>&1; then
        log_error "Network listing test failed"
        return 1
    fi
    
    # Test pool listing
    if ! virsh pool-list --all > /dev/null 2>&1; then
        log_error "Pool listing test failed"
        return 1
    fi
    
    log_success "Libvirt installation test passed"
}

# Main execution
main() {
    log_step "Starting libvirt setup..."
    
    check_root
    check_virtualization
    install_libvirt_packages
    configure_libvirt
    create_default_network
    configure_storage_pools
    configure_firewall
    create_helper_scripts
    test_libvirt
    
    log_success "Libvirt setup completed successfully!"
    log_info "You can now use 'virsh' commands to manage virtual machines"
    log_info "Helper scripts available: vm-manager, network-manager"
}

# Run main function
main "$@"
