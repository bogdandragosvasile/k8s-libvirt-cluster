#!/bin/bash

# Prerequisites Installation Script for K8s Libvirt Cluster
# Version: 1.1.1
# Description: Transforms a fresh Ubuntu 25.04 system into a fully functional development environment
# Author: Bogdan Dragos Vasile

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
CONFIGS_DIR="${SCRIPT_DIR}/configs"
LOG_FILE="/tmp/prerequisites-install.log"
START_TIME=$(date +%s)

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check system requirements
check_system_requirements() {
    log_step "Checking system requirements..."
    
    # Check OS
    if ! grep -q "Ubuntu 25.04" /etc/os-release 2>/dev/null; then
        log_warning "This script is designed for Ubuntu 25.04. Other versions may work but are not tested."
    fi
    
    # Check CPU virtualization
    if ! egrep -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        log_error "Hardware virtualization (VT-x/AMD-V) is not available or not enabled in BIOS"
        exit 1
    fi
    
    # Check available memory
    MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $MEM_GB -lt 8 ]]; then
        log_warning "Less than 8GB RAM detected. Performance may be affected."
    fi
    
    # Check available disk space
    DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_GB -lt 50 ]]; then
        log_warning "Less than 50GB free space detected. Consider freeing up space."
    fi
    
    log_success "System requirements check completed"
}

# Create backup of important files
create_backups() {
    log_step "Creating backups of important configuration files..."
    
    BACKUP_DIR="/root/prerequisites-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup important files
    [[ -f /etc/ssh/sshd_config ]] && cp /etc/ssh/sshd_config "$BACKUP_DIR/"
    [[ -f /etc/fstab ]] && cp /etc/fstab "$BACKUP_DIR/"
    [[ -f /etc/hosts ]] && cp /etc/hosts "$BACKUP_DIR/"
    
    log_success "Backups created in $BACKUP_DIR"
}

# Function to run individual scripts
run_script() {
    local script_name="$1"
    local script_path="${SCRIPTS_DIR}/${script_name}"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        return 1
    fi
    
    log_step "Running $script_name..."
    
    # Make script executable
    chmod +x "$script_path"
    
    # Run script and capture output
    if "$script_path" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "$script_name completed successfully"
        return 0
    else
        log_error "$script_name failed"
        return 1
    fi
}

# Main installation function
main_installation() {
    log_step "Starting prerequisites installation..."
    
    # Array of scripts to run in order
    local scripts=(
        "01-system-update.sh"
        "02-libvirt-setup.sh"
        "03-docker-setup.sh"
        "04-jenkins-setup.sh"
        "05-kubernetes-tools.sh"
        "06-terraform-setup.sh"
        "07-development-tools.sh"
        "08-final-config.sh"
    )
    
    # Run each script
    for script in "${scripts[@]}"; do
        if ! run_script "$script"; then
            log_error "Installation failed at script: $script"
            log_error "Check the log file: $LOG_FILE"
            exit 1
        fi
    done
}

# Verification function
verify_installation() {
    log_step "Verifying installation..."
    
    local errors=0
    
    # Check libvirt
    if ! virsh list --all > /dev/null 2>&1; then
        log_error "Libvirt verification failed"
        ((errors++))
    fi
    
    # Check docker
    if ! docker --version > /dev/null 2>&1; then
        log_error "Docker verification failed"
        ((errors++))
    fi
    
    # Check jenkins
    if ! systemctl is-active --quiet jenkins; then
        log_error "Jenkins service is not running"
        ((errors++))
    fi
    
    # Check kubectl
    if ! kubectl version --client > /dev/null 2>&1; then
        log_error "kubectl verification failed"
        ((errors++))
    fi
    
    # Check terraform
    if ! terraform version > /dev/null 2>&1; then
        log_error "Terraform verification failed"
        ((errors++))
    fi
    
    # Check helm
    if ! helm version > /dev/null 2>&1; then
        log_error "Helm verification failed"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "All verifications passed!"
        return 0
    else
        log_error "$errors verification(s) failed"
        return 1
    fi
}

# Print final summary
print_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo
    echo "=========================================="
    echo "           INSTALLATION SUMMARY"
    echo "=========================================="
    echo "Duration: ${minutes}m ${seconds}s"
    echo "Log file: $LOG_FILE"
    echo
    echo "Installed components:"
    echo "✅ Libvirt/QEMU/KVM"
    echo "✅ Docker"
    echo "✅ Jenkins"
    echo "✅ kubectl"
    echo "✅ Terraform"
    echo "✅ Helm"
    echo "✅ Development tools"
    echo
    echo "Next steps:"
    echo "1. Reboot the system: sudo reboot"
    echo "2. Access Jenkins: http://localhost:8080"
    echo "3. Check the installation checklist in README.md"
    echo "4. Start using the Kubernetes Libvirt Cluster"
    echo
    echo "For troubleshooting, check: $LOG_FILE"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    echo "  K8s Libvirt Cluster - Prerequisites"
    echo "  Installation Script v1.1.1"
    echo "=========================================="
    echo
    
    # Initialize log file
    echo "Installation started at $(date)" > "$LOG_FILE"
    
    # Run installation steps
    check_root
    check_system_requirements
    create_backups
    main_installation
    verify_installation
    
    # Print summary
    print_summary
    
    log_success "Installation completed successfully!"
}

# Handle script interruption
trap 'log_error "Installation interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"



