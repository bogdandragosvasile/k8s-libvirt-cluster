#!/bin/bash

# Docker Setup Script for K8s Libvirt Cluster
# Version: 1.0.0
# Description: Installs and configures Docker for containerization

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

# Remove old Docker versions
remove_old_docker() {
    log_step "Removing old Docker versions..."
    
    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    log_success "Old Docker versions removed"
}

# Install Docker dependencies
install_docker_dependencies() {
    log_step "Installing Docker dependencies..."
    
    # Update package list
    apt update
    
    # Install required packages
    DEBIAN_FRONTEND=noninteractive apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    
    log_success "Docker dependencies installed"
}

# Add Docker GPG key and repository
setup_docker_repository() {
    log_step "Setting up Docker repository..."
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list
    apt update
    
    log_success "Docker repository configured"
}

# Install Docker
install_docker() {
    log_step "Installing Docker..."
    
    # Install Docker Engine
    DEBIAN_FRONTEND=noninteractive apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    log_success "Docker installed"
}

# Configure Docker
configure_docker() {
    log_step "Configuring Docker..."
    
    # Start and enable Docker service
    systemctl enable docker
    systemctl start docker
    
    # Add current user to docker group
    usermod -a -G docker $SUDO_USER
    
    # Create Docker daemon configuration
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  },
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "metrics-addr": "127.0.0.1:9323",
  "insecure-registries": [],
  "registry-mirrors": []
}
EOF

    # Restart Docker daemon
    systemctl restart docker
    
    log_success "Docker configured"
}

# Install Docker Compose
install_docker_compose() {
    log_step "Installing Docker Compose..."
    
    # Install Docker Compose v2 (already included with docker-compose-plugin)
    # Install standalone Docker Compose v1 for compatibility
    curl -L "https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for docker-compose v1 compatibility
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker Compose installed"
}

# Configure firewall for Docker
configure_firewall() {
    log_step "Configuring firewall for Docker..."
    
    # Allow Docker traffic
    ufw allow 2375/tcp  # Docker daemon unencrypted
    ufw allow 2376/tcp  # Docker daemon encrypted
    ufw allow 9323/tcp  # Docker metrics
    
    log_success "Firewall configured for Docker"
}

# Create Docker helper scripts
create_helper_scripts() {
    log_step "Creating Docker helper scripts..."
    
    # Create Docker management script
    cat > /usr/local/bin/docker-manager << 'EOF'
#!/bin/bash

# Docker Management Helper Script
# Usage: docker-manager [ps|images|volumes|networks|cleanup|stats] [options]

case "$1" in
    ps)
        docker ps -a
        ;;
    images)
        docker images
        ;;
    volumes)
        docker volume ls
        ;;
    networks)
        docker network ls
        ;;
    cleanup)
        echo "Cleaning up Docker resources..."
        docker system prune -f
        docker volume prune -f
        docker network prune -f
        echo "Cleanup completed"
        ;;
    stats)
        docker stats --no-stream
        ;;
    info)
        docker info
        ;;
    *)
        echo "Usage: docker-manager [ps|images|volumes|networks|cleanup|stats|info]"
        echo "Commands:"
        echo "  ps       - List all containers"
        echo "  images   - List all images"
        echo "  volumes  - List all volumes"
        echo "  networks - List all networks"
        echo "  cleanup  - Clean up unused resources"
        echo "  stats    - Show container statistics"
        echo "  info     - Show Docker system information"
        ;;
esac
EOF

    chmod +x /usr/local/bin/docker-manager
    
    # Create Docker health check script
    cat > /usr/local/bin/docker-health << 'EOF'
#!/bin/bash

# Docker Health Check Script

echo "=== Docker Health Check ==="
echo

echo "1. Docker daemon status:"
systemctl is-active docker
echo

echo "2. Docker version:"
docker --version
echo

echo "3. Docker info:"
docker info | head -20
echo

echo "4. Running containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

echo "5. Docker disk usage:"
docker system df
echo

echo "6. Docker daemon logs (last 10 lines):"
journalctl -u docker --no-pager -n 10
EOF

    chmod +x /usr/local/bin/docker-health
    
    log_success "Helper scripts created"
}

# Test Docker installation
test_docker() {
    log_step "Testing Docker installation..."
    
    # Test Docker daemon
    if ! systemctl is-active --quiet docker; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    # Test Docker version
    if ! docker --version > /dev/null 2>&1; then
        log_error "Docker version test failed"
        return 1
    fi
    
    # Test Docker info
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker info test failed"
        return 1
    fi
    
    # Test Docker Compose
    if ! docker-compose --version > /dev/null 2>&1; then
        log_error "Docker Compose test failed"
        return 1
    fi
    
    # Test running a simple container
    if ! docker run --rm hello-world > /dev/null 2>&1; then
        log_error "Docker container test failed"
        return 1
    fi
    
    log_success "Docker installation test passed"
}

# Install useful Docker images
install_useful_images() {
    log_step "Installing useful Docker images..."
    
    # Pull commonly used images
    docker pull hello-world
    docker pull alpine:latest
    docker pull ubuntu:latest
    docker pull nginx:alpine
    docker pull redis:alpine
    docker pull postgres:latest
    docker pull mysql:latest
    
    log_success "Useful Docker images installed"
}

# Main execution
main() {
    log_step "Starting Docker setup..."
    
    check_root
    remove_old_docker
    install_docker_dependencies
    setup_docker_repository
    install_docker
    configure_docker
    install_docker_compose
    configure_firewall
    create_helper_scripts
    test_docker
    install_useful_images
    
    log_success "Docker setup completed successfully!"
    log_info "You can now use 'docker' commands to manage containers"
    log_info "Helper scripts available: docker-manager, docker-health"
    log_info "Remember to log out and back in for group changes to take effect"
}

# Run main function
main "$@"

