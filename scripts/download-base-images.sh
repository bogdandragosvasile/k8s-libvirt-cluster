#!/bin/bash

# =============================================================================
# Automated Base Image Download for k8s-libvirt-cluster
# =============================================================================
# This script downloads and prepares base images for different Linux distributions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
IMAGES_DIR="/var/lib/libvirt/images"
TEMP_DIR="/tmp/k8s-base-images"

# Logging functions
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
# Distribution Image Configurations
# =============================================================================

declare -A DISTRO_IMAGES=(
    # Ubuntu distributions
    ["ubuntu-24.04"]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img ubuntu-24.04-server-cloudimg-amd64.img"
    ["ubuntu-22.04"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img ubuntu-22.04-server-cloudimg-amd64.img"
    ["ubuntu-20.04"]="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img ubuntu-20.04-server-cloudimg-amd64.img"
    
    # CentOS distributions
    ["centos-9"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 centos-9-stream-cloudimg-amd64.img"
    ["centos-8"]="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2 centos-8-stream-cloudimg-amd64.img"
    
    # Rocky Linux distributions  
    ["rocky-9"]="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 rocky-9-cloudimg-amd64.img"
    ["rocky-8"]="https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2 rocky-8-cloudimg-amd64.img"
    
    # Debian distributions
    ["debian-12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 debian-12-cloudimg-amd64.img"
    ["debian-11"]="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2 debian-11-cloudimg-amd64.img"
    
    # openSUSE distributions
    ["opensuse-15.5"]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5-OpenStack.x86_64.qcow2 opensuse-leap-15.5-cloudimg-amd64.img"
    ["opensuse-15.4"]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4-OpenStack.x86_64.qcow2 opensuse-leap-15.4-cloudimg-amd64.img"
)

# =============================================================================
# Helper Functions
# =============================================================================

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
    fi
    
    # Check required commands
    local required_commands=("wget" "curl" "qemu-img")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "Required command '$cmd' not found. Please install it first."
        fi
    done
    
    # Create directories
    mkdir -p "$IMAGES_DIR"
    mkdir -p "$TEMP_DIR"
    
    success "Prerequisites checked"
}

download_image() {
    local distro="$1"
    local url_and_filename="${DISTRO_IMAGES[$distro]}"
    local url=$(echo "$url_and_filename" | cut -d' ' -f1)
    local filename=$(echo "$url_and_filename" | cut -d' ' -f2)
    local temp_file="$TEMP_DIR/$(basename "$url")"
    local final_file="$IMAGES_DIR/$filename"
    
    log "Downloading $distro image..."
    
    # Check if image already exists
    if [[ -f "$final_file" ]]; then
        log "Image $filename already exists. Checking if update needed..."
        
        # Download to temp first to compare
        if wget --timestamping --directory-prefix="$TEMP_DIR" "$url"; then
            if [[ "$temp_file" -nt "$final_file" ]]; then
                log "Newer image found, updating..."
                mv "$temp_file" "$final_file"
            else
                log "Image is up to date"
                rm -f "$temp_file"
                return 0
            fi
        else
            warn "Failed to check for updates, using existing image"
            return 0
        fi
    else
        # Download new image
        if wget --directory-prefix="$TEMP_DIR" "$url"; then
            mv "$temp_file" "$final_file"
        else
            error "Failed to download $distro image from $url"
        fi
    fi
    
    # Verify the image
    if qemu-img info "$final_file" >/dev/null 2>&1; then
        success "Downloaded and verified $distro image"
    else
        error "Downloaded image $final_file appears to be corrupted"
    fi
    
    # Set proper permissions
    chmod 644 "$final_file"
    chown libvirt-qemu:kvm "$final_file" 2>/dev/null || true
}

list_available_distros() {
    echo -e "${BLUE}Available distributions:${NC}"
    for distro in "${!DISTRO_IMAGES[@]}"; do
        echo "  - $distro"
    done | sort
}

show_image_info() {
    log "Current base images in $IMAGES_DIR:"
    echo
    for distro in "${!DISTRO_IMAGES[@]}"; do
        local url_and_filename="${DISTRO_IMAGES[$distro]}"
        local filename=$(echo "$url_and_filename" | cut -d' ' -f2)
        local filepath="$IMAGES_DIR/$filename"
        
        if [[ -f "$filepath" ]]; then
            local size=$(du -h "$filepath" | cut -f1)
            local date=$(stat -c %y "$filepath" | cut -d' ' -f1)
            echo -e "${GREEN}✓${NC} $distro: $filename ($size, $date)"
        else
            echo -e "${RED}✗${NC} $distro: $filename (not downloaded)"
        fi
    done | sort
    echo
}

# =============================================================================
# Main Functions
# =============================================================================

download_all_images() {
    log "Downloading all available distribution images..."
    
    local total=${#DISTRO_IMAGES[@]}
    local current=0
    
    for distro in "${!DISTRO_IMAGES[@]}"; do
        ((current++))
        log "Progress: $current/$total - Processing $distro"
        download_image "$distro"
    done
    
    success "All images downloaded successfully!"
}

download_specific_images() {
    local distros=("$@")
    
    for distro in "${distros[@]}"; do
        if [[ -n "${DISTRO_IMAGES[$distro]:-}" ]]; then
            download_image "$distro"
        else
            error "Unknown distribution: $distro"
        fi
    done
}

cleanup_old_images() {
    log "Cleaning up old/unused images..."
    
    local removed=0
    
    # Find images in the directory that don't match our current naming scheme
    for file in "$IMAGES_DIR"/*.{img,qcow2} 2>/dev/null; do
        [[ -f "$file" ]] || continue
        
        local basename=$(basename "$file")
        local found=false
        
        # Check if this file matches any of our current images
        for distro in "${!DISTRO_IMAGES[@]}"; do
            local url_and_filename="${DISTRO_IMAGES[$distro]}"
            local filename=$(echo "$url_and_filename" | cut -d' ' -f2)
            
            if [[ "$basename" == "$filename" ]]; then
                found=true
                break
            fi
        done
        
        if [[ "$found" == "false" ]]; then
            read -p "Remove unused image $basename? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -f "$file"
                log "Removed $basename"
                ((removed++))
            fi
        fi
    done
    
    if [[ $removed -gt 0 ]]; then
        success "Cleaned up $removed old images"
    else
        log "No old images to clean up"
    fi
}

# =============================================================================
# Main Script
# =============================================================================

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [DISTROS...]

Download and manage base images for k8s-libvirt-cluster deployment.

OPTIONS:
    -a, --all           Download all available distribution images
    -l, --list          List available distributions
    -i, --info          Show information about current images
    -c, --cleanup       Clean up old/unused images
    -h, --help          Show this help message

DISTROS:
    Specific distribution names to download (e.g., ubuntu-24.04, centos-9)

EXAMPLES:
    $0 --all                    # Download all images
    $0 ubuntu-24.04 centos-9    # Download specific images
    $0 --list                   # List available distributions
    $0 --info                   # Show current image status
    $0 --cleanup                # Remove old images

EOF
}

main() {
    check_prerequisites
    
    case "${1:-}" in
        -a|--all)
            download_all_images
            show_image_info
            ;;
        -l|--list)
            list_available_distros
            ;;
        -i|--info)
            show_image_info
            ;;
        -c|--cleanup)
            cleanup_old_images
            ;;
        -h|--help|"")
            show_help
            ;;
        *)
            # Download specific distributions
            if [[ $# -eq 0 ]]; then
                show_help
                exit 1
            fi
            
            download_specific_images "$@"
            show_image_info
            ;;
    esac
    
    # Cleanup temp directory
    rm -rf "$TEMP_DIR"
}

# Run main function with all arguments
main "$@"
