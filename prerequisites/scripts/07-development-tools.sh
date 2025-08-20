#!/bin/bash
set -euo pipefail

# Color definitions
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

# Script information
SCRIPT_NAME="Development Tools Setup"
SCRIPT_VERSION="1.0.0"

log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Go
install_go() {
    log_step "Installing Go programming language..."
    
    if command_exists go; then
        log_info "Go is already installed: $(go version)"
        return 0
    fi
    
    # Download and install Go
    GO_VERSION="1.21.5"
    GO_ARCH="linux-amd64"
    
    log_info "Downloading Go $GO_VERSION..."
    wget -q "https://go.dev/dl/go${GO_VERSION}.${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz
    
    log_info "Installing Go to /usr/local..."
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile.d/go.sh
    export PATH=$PATH:/usr/local/go/bin
    
    # Clean up
    rm -f /tmp/go.tar.gz
    
    log_success "Go installed successfully: $(go version)"
}

# Function to install Node.js and npm
install_nodejs() {
    log_step "Installing Node.js and npm..."
    
    if command_exists node && command_exists npm; then
        log_info "Node.js is already installed: $(node --version)"
        log_info "npm is already installed: $(npm --version)"
        return 0
    fi
    
    # Install Node.js using NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    # Install additional npm packages globally
    log_info "Installing useful npm packages..."
    sudo npm install -g yarn pnpm typescript ts-node nodemon
    
    log_success "Node.js installed successfully: $(node --version)"
    log_success "npm installed successfully: $(npm --version)"
}

# Function to install Python development tools
install_python_tools() {
    log_step "Installing Python development tools..."
    
    # Install pip if not present
    if ! command_exists pip3; then
        sudo apt-get install -y python3-pip
    fi
    
    # Install useful Python packages
    log_info "Installing Python development packages..."
    sudo pip3 install --break-system-packages \
        requests \
        beautifulsoup4 \
        pandas \
        numpy \
        matplotlib \
        jupyter \
        ipython \
        pytest \
        black \
        flake8 \
        mypy \
        pre-commit
    
    log_success "Python development tools installed successfully"
}

# Function to install additional development tools
install_dev_tools() {
    log_step "Installing additional development tools..."
    
    # Install additional useful tools
    sudo apt-get install -y \
        git-lfs \
        ripgrep \
        fd-find \
        bat \
        exa \
        fzf \
        htop \
        iotop \
        ncdu \
        tree \
        tmux \
        vim \
        nano \
        curl \
        wget \
        jq \
        yq \
        httpie \
        socat \
        netcat \
        telnet \
        traceroute \
        mtr \
        nmap \
        tcpdump \
        wireshark \
        sqlite3 \
        postgresql-client \
        mysql-client \
        redis-tools \
        mongodb-clients \
        elasticsearch-curator
    
    log_success "Additional development tools installed successfully"
}

# Function to install container tools
install_container_tools() {
    log_step "Installing container development tools..."
    
    # Install Podman (alternative to Docker)
    if ! command_exists podman; then
        log_info "Installing Podman..."
        sudo apt-get install -y podman podman-compose
    fi
    
    # Install Buildah
    if ! command_exists buildah; then
        log_info "Installing Buildah..."
        sudo apt-get install -y buildah
    fi
    
    # Install Skopeo
    if ! command_exists skopeo; then
        log_info "Installing Skopeo..."
        sudo apt-get install -y skopeo
    fi
    
    # Install Dive (Docker image analyzer)
    if ! command_exists dive; then
        log_info "Installing Dive..."
        wget -q https://github.com/wagoodman/dive/releases/download/v0.9.2/dive_0.9.2_linux_amd64.deb -O /tmp/dive.deb
        sudo dpkg -i /tmp/dive.deb
        rm -f /tmp/dive.deb
    fi
    
    # Install Trivy (vulnerability scanner)
    if ! command_exists trivy; then
        log_info "Installing Trivy..."
        sudo apt-get install -y wget apt-transport-https gnupg lsb-release
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
        sudo apt-get update
        sudo apt-get install -y trivy
    fi
    
    log_success "Container development tools installed successfully"
}

# Function to install monitoring and debugging tools
install_monitoring_tools() {
    log_step "Installing monitoring and debugging tools..."
    
    # Install Prometheus tools
    if ! command_exists promtool; then
        log_info "Installing Prometheus tools..."
        wget -q https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz
        sudo tar -xzf /tmp/prometheus.tar.gz -C /usr/local --strip-components=1 prometheus-2.48.0.linux-amd64/promtool
        rm -f /tmp/prometheus.tar.gz
    fi
    
    # Install Grafana CLI
    if ! command_exists grafana-cli; then
        log_info "Installing Grafana CLI..."
        wget -q https://github.com/grafana/grafana/releases/download/v10.2.0/grafana-10.2.0.linux-amd64.tar.gz -O /tmp/grafana.tar.gz
        sudo tar -xzf /tmp/grafana.tar.gz -C /usr/local --strip-components=1 grafana-10.2.0/bin/grafana-cli
        rm -f /tmp/grafana.tar.gz
    fi
    
    # Install Jaeger CLI
    if ! command_exists jaeger; then
        log_info "Installing Jaeger CLI..."
        wget -q https://github.com/jaegertracing/jaeger/releases/download/v1.48.0/jaeger-1.48.0-linux-amd64.tar.gz -O /tmp/jaeger.tar.gz
        sudo tar -xzf /tmp/jaeger.tar.gz -C /usr/local --strip-components=1 jaeger-1.48.0-linux-amd64/jaeger
        rm -f /tmp/jaeger.tar.gz
    fi
    
    # Install additional monitoring tools
    sudo apt-get install -y \
        sysstat \
        iostat \
        vmstat \
        sar \
        pidstat \
        mpstat \
        iotop \
        iftop \
        nethogs \
        nload \
        bmon \
        vnstat \
        dstat
    
    log_success "Monitoring and debugging tools installed successfully"
}

# Function to install cloud tools
install_cloud_tools() {
    log_step "Installing cloud development tools..."
    
    # Install AWS CLI
    if ! command_exists aws; then
        log_info "Installing AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
        unzip -q /tmp/awscliv2.zip -d /tmp
        sudo /tmp/aws/install
        rm -rf /tmp/aws /tmp/awscliv2.zip
    fi
    
    # Install Azure CLI
    if ! command_exists az; then
        log_info "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi
    
    # Install Google Cloud SDK
    if ! command_exists gcloud; then
        log_info "Installing Google Cloud SDK..."
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
        sudo apt-get update && sudo apt-get install -y google-cloud-cli
    fi
    
    # Install DigitalOcean CLI
    if ! command_exists doctl; then
        log_info "Installing DigitalOcean CLI..."
        wget -q https://github.com/digitalocean/doctl/releases/download/v1.98.0/doctl-1.98.0-linux-amd64.tar.gz -O /tmp/doctl.tar.gz
        sudo tar -xzf /tmp/doctl.tar.gz -C /usr/local/bin
        rm -f /tmp/doctl.tar.gz
    fi
    
    log_success "Cloud development tools installed successfully"
}

# Function to create helper scripts
create_helper_scripts() {
    log_step "Creating development helper scripts..."
    
    # Create development tools manager script
    sudo tee /usr/local/bin/dev-manager > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

# Color definitions
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

show_usage() {
    cat << 'USAGE'
Development Tools Manager

Usage: dev-manager [COMMAND] [OPTIONS]

Commands:
  status          Show status of all development tools
  update          Update all development tools
  clean           Clean up temporary files and caches
  test            Test all development tools
  help            Show this help message

Examples:
  dev-manager status
  dev-manager update
  dev-manager clean
  dev-manager test
USAGE
}

check_tool_status() {
    local tool=$1
    local version_cmd=$2
    
    if command -v "$tool" >/dev/null 2>&1; then
        local version
        version=$($version_cmd 2>/dev/null | head -n1 || echo "version unknown")
        log_success "$tool: $version"
    else
        log_error "$tool: not installed"
    fi
}

show_status() {
    log_info "Checking development tools status..."
    
    echo "=== Programming Languages ==="
    check_tool_status "go" "go version"
    check_tool_status "node" "node --version"
    check_tool_status "npm" "npm --version"
    check_tool_status "python3" "python3 --version"
    check_tool_status "pip3" "pip3 --version"
    
    echo -e "\n=== Container Tools ==="
    check_tool_status "docker" "docker --version"
    check_tool_status "podman" "podman --version"
    check_tool_status "buildah" "buildah --version"
    check_tool_status "skopeo" "skopeo --version"
    check_tool_status "dive" "dive --version"
    check_tool_status "trivy" "trivy --version"
    
    echo -e "\n=== Cloud Tools ==="
    check_tool_status "aws" "aws --version"
    check_tool_status "az" "az version"
    check_tool_status "gcloud" "gcloud --version"
    check_tool_status "doctl" "doctl version"
    
    echo -e "\n=== Development Tools ==="
    check_tool_status "git" "git --version"
    check_tool_status "terraform" "terraform --version"
    check_tool_status "kubectl" "kubectl version --client"
    check_tool_status "helm" "helm version"
}

update_tools() {
    log_info "Updating development tools..."
    
    # Update system packages
    sudo apt-get update && sudo apt-get upgrade -y
    
    # Update Go
    if command -v go >/dev/null 2>&1; then
        log_info "Updating Go..."
        go install golang.org/dl/go@latest
    fi
    
    # Update Node.js packages
    if command -v npm >/dev/null 2>&1; then
        log_info "Updating npm packages..."
        sudo npm update -g
    fi
    
    # Update Python packages
    if command -v pip3 >/dev/null 2>&1; then
        log_info "Updating Python packages..."
        sudo pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 sudo pip3 install -U
    fi
    
    log_success "Development tools updated successfully"
}

clean_tools() {
    log_info "Cleaning development tools..."
    
    # Clean npm cache
    if command -v npm >/dev/null 2>&1; then
        npm cache clean --force
    fi
    
    # Clean pip cache
    if command -v pip3 >/dev/null 2>&1; then
        pip3 cache purge
    fi
    
    # Clean Go cache
    if command -v go >/dev/null 2>&1; then
        go clean -cache -modcache -testcache
    fi
    
    # Clean Docker
    if command -v docker >/dev/null 2>&1; then
        docker system prune -f
    fi
    
    # Clean temporary files
    sudo rm -rf /tmp/*
    
    log_success "Development tools cleaned successfully"
}

test_tools() {
    log_info "Testing development tools..."
    
    # Test Go
    if command -v go >/dev/null 2>&1; then
        log_info "Testing Go..."
        go version
    fi
    
    # Test Node.js
    if command -v node >/dev/null 2>&1; then
        log_info "Testing Node.js..."
        node --version
        npm --version
    fi
    
    # Test Python
    if command -v python3 >/dev/null 2>&1; then
        log_info "Testing Python..."
        python3 --version
        pip3 --version
    fi
    
    # Test container tools
    if command -v docker >/dev/null 2>&1; then
        log_info "Testing Docker..."
        docker --version
        docker run --rm hello-world
    fi
    
    log_success "Development tools tested successfully"
}

# Main function
main() {
    case "${1:-help}" in
        status)
            show_status
            ;;
        update)
            update_tools
            ;;
        clean)
            clean_tools
            ;;
        test)
            test_tools
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
EOF

    sudo chmod +x /usr/local/bin/dev-manager
    
    # Create development environment checker script
    sudo tee /usr/local/bin/dev-check > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

# Color definitions
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

echo "=== Development Environment Health Check ==="
echo

# Check system resources
log_info "System Resources:"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $4}') available"
echo

# Check essential services
log_info "Essential Services:"
services=("libvirtd" "docker" "jenkins")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_success "$service: running"
    else
        log_error "$service: not running"
    fi
done
echo

# Check network connectivity
log_info "Network Connectivity:"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_success "Internet: connected"
else
    log_error "Internet: disconnected"
fi

if ping -c 1 google.com >/dev/null 2>&1; then
    log_success "DNS: working"
else
    log_error "DNS: not working"
fi
echo

# Check development tools
log_info "Development Tools:"
tools=("git" "docker" "kubectl" "terraform" "helm" "jenkins")
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        log_success "$tool: installed"
    else
        log_error "$tool: not installed"
    fi
done
echo

# Check Kubernetes cluster
log_info "Kubernetes Cluster:"
if command -v kubectl >/dev/null 2>&1; then
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Kubernetes: connected"
        echo "  Nodes: $(kubectl get nodes --no-headers | wc -l)"
        echo "  Pods: $(kubectl get pods --all-namespaces --no-headers | wc -l)"
    else
        log_warning "Kubernetes: not connected"
    fi
else
    log_error "Kubernetes: kubectl not installed"
fi
echo

# Check libvirt VMs
log_info "Libvirt Virtual Machines:"
if command -v virsh >/dev/null 2>&1; then
    vm_count=$(sudo virsh list --all --name | grep -v "^$" | wc -l)
    running_count=$(sudo virsh list --name | grep -v "^$" | wc -l)
    log_success "VMs: $vm_count total, $running_count running"
else
    log_error "Libvirt: virsh not installed"
fi
echo

log_info "Health check completed!"
EOF

    sudo chmod +x /usr/local/bin/dev-check
    
    log_success "Development helper scripts created successfully"
}

# Function to test all installed tools
test_installation() {
    log_step "Testing development tools installation..."
    
    # Test Go
    if command_exists go; then
        log_info "Testing Go..."
        go version
    fi
    
    # Test Node.js
    if command_exists node; then
        log_info "Testing Node.js..."
        node --version
        npm --version
    fi
    
    # Test Python tools
    if command_exists python3; then
        log_info "Testing Python..."
        python3 --version
        pip3 --version
    fi
    
    # Test container tools
    if command_exists podman; then
        log_info "Testing Podman..."
        podman --version
    fi
    
    if command_exists dive; then
        log_info "Testing Dive..."
        dive --version
    fi
    
    # Test cloud tools
    if command_exists aws; then
        log_info "Testing AWS CLI..."
        aws --version
    fi
    
    if command_exists az; then
        log_info "Testing Azure CLI..."
        az version
    fi
    
    # Test helper scripts
    if command_exists dev-manager; then
        log_info "Testing dev-manager..."
        dev-manager status
    fi
    
    if command_exists dev-check; then
        log_info "Testing dev-check..."
        dev-check
    fi
    
    log_success "All development tools tested successfully"
}

# Main function
main() {
    log_info "Starting development tools installation..."
    
    # Update package lists
    log_step "Updating package lists..."
    sudo apt-get update
    
    # Install Go
    install_go
    
    # Install Node.js and npm
    install_nodejs
    
    # Install Python development tools
    install_python_tools
    
    # Install additional development tools
    install_dev_tools
    
    # Install container tools
    install_container_tools
    
    # Install monitoring and debugging tools
    install_monitoring_tools
    
    # Install cloud tools
    install_cloud_tools
    
    # Create helper scripts
    create_helper_scripts
    
    # Test installation
    test_installation
    
    log_success "Development tools installation completed successfully!"
    log_info "You can now use:"
    log_info "  - dev-manager status    # Check tool status"
    log_info "  - dev-manager update    # Update tools"
    log_info "  - dev-manager clean     # Clean caches"
    log_info "  - dev-manager test      # Test tools"
    log_info "  - dev-check            # Health check"
}

# Run main function
main "$@"
