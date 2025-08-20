#!/bin/bash

# Kubernetes Tools Setup Script for K8s Libvirt Cluster
# Version: 1.0.0
# Description: Installs kubectl, kubeadm, and other Kubernetes tools

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

# Install kubectl
install_kubectl() {
    log_step "Installing kubectl..."
    
    # Download kubectl binary
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Install kubectl
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Clean up
    rm -f kubectl
    
    log_success "kubectl installed"
}

# Install kubeadm, kubelet, and kubectl
install_kubeadm() {
    log_step "Installing kubeadm, kubelet, and kubectl..."
    
    # Update package list
    apt update
    
    # Install required packages
    DEBIAN_FRONTEND=noninteractive apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gpg
    
    # Add Kubernetes GPG key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Add Kubernetes repository
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    
    # Update package list
    apt update
    
    # Install kubeadm, kubelet, and kubectl
    DEBIAN_FRONTEND=noninteractive apt install -y \
        kubelet \
        kubeadm \
        kubectl
    
    # Hold packages to prevent automatic updates
    apt-mark hold kubelet kubeadm kubectl
    
    log_success "kubeadm, kubelet, and kubectl installed"
}

# Install containerd
install_containerd() {
    log_step "Installing containerd..."
    
    # Update package list
    apt update
    
    # Install containerd
    DEBIAN_FRONTEND=noninteractive apt install -y containerd
    
    # Create containerd configuration
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    
    # Configure containerd to use systemd cgroup driver
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Restart containerd
    systemctl restart containerd
    systemctl enable containerd
    
    log_success "containerd installed and configured"
}

# Install Helm
install_helm() {
    log_step "Installing Helm..."
    
    # Download and install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_success "Helm installed"
}

# Install k9s (Kubernetes CLI tool)
install_k9s() {
    log_step "Installing k9s..."
    
    # Download k9s
    curl -sS https://webinstall.dev/k9s | bash
    
    # Create symlink
    ln -sf ~/.local/bin/k9s /usr/local/bin/k9s
    
    log_success "k9s installed"
}

# Install kubectx and kubens
install_kubectx() {
    log_step "Installing kubectx and kubens..."
    
    # Install kubectx and kubens
    git clone https://github.com/ahmetb/kubectx /opt/kubectx
    ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
    ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
    
    log_success "kubectx and kubens installed"
}

# Install kubectl plugins
install_kubectl_plugins() {
    log_step "Installing kubectl plugins..."
    
    # Create kubectl plugins directory
    mkdir -p ~/.local/share/kubectl/plugins
    
    # Install kubectl-tree
    curl -L https://github.com/ahmetb/kubectl-tree/releases/download/v0.4.4/kubectl-tree_v0.4.4_linux_amd64.tar.gz | tar -xz
    mv kubectl-tree ~/.local/share/kubectl/plugins/
    chmod +x ~/.local/share/kubectl/plugins/kubectl-tree
    
    # Install kubectl-neat
    curl -L https://github.com/itaysk/kubectl-neat/releases/download/v2.0.3/kubectl-neat_linux_amd64.tar.gz | tar -xz
    mv kubectl-neat ~/.local/share/kubectl/plugins/
    chmod +x ~/.local/share/kubectl/plugins/kubectl-neat
    
    # Install kubectl-view-secret
    curl -L https://github.com/elsesiy/kubectl-view-secret/releases/download/v0.1.0/kubectl-view-secret_0.1.0_linux_amd64.tar.gz | tar -xz
    mv kubectl-view-secret ~/.local/share/kubectl/plugins/
    chmod +x ~/.local/share/kubectl/plugins/kubectl-view-secret
    
    log_success "kubectl plugins installed"
}

# Install additional Kubernetes tools
install_additional_tools() {
    log_step "Installing additional Kubernetes tools..."
    
    # Install kubectl-ctx and kubectl-ns (alternative to kubectx/kubens)
    curl -L https://github.com/ahmetb/kubectx/releases/download/v0.9.5/kubectx_v0.9.5_linux_x86_64.tar.gz | tar -xz
    mv kubectx /usr/local/bin/
    mv kubens /usr/local/bin/
    chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens
    
    # Install kubectl-aliases
    curl -L https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases -o /etc/bash_completion.d/kubectl_aliases
    
    # Install kubectl completion
    kubectl completion bash > /etc/bash_completion.d/kubectl
    
    # Install stern (log tailing)
    curl -L https://github.com/stern/stern/releases/download/v1.27.0/stern_1.27.0_linux_amd64.tar.gz | tar -xz
    mv stern /usr/local/bin/
    chmod +x /usr/local/bin/stern
    
    # Install kubeval (YAML validation)
    curl -L https://github.com/instrumenta/kubeval/releases/download/v0.16.1/kubeval-linux-amd64.tar.gz | tar -xz
    mv kubeval /usr/local/bin/
    chmod +x /usr/local/bin/kubeval
    
    # Install kustomize
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    mv kustomize /usr/local/bin/
    chmod +x /usr/local/bin/kustomize
    
    log_success "Additional Kubernetes tools installed"
}

# Configure kubectl
configure_kubectl() {
    log_step "Configuring kubectl..."
    
    # Create kubectl configuration directory
    mkdir -p ~/.kube
    
    # Set kubectl configuration
    export KUBECONFIG=/etc/kubernetes/admin.conf
    
    # Add kubectl configuration to environment
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /etc/environment
    
    log_success "kubectl configured"
}

# Create Kubernetes helper scripts
create_helper_scripts() {
    log_step "Creating Kubernetes helper scripts..."
    
    # Create kubectl management script
    cat > /usr/local/bin/k8s-manager << 'EOF'
#!/bin/bash

# Kubernetes Management Helper Script
# Usage: k8s-manager [nodes|pods|services|deployments|logs|exec|port-forward] [options]

case "$1" in
    nodes)
        kubectl get nodes -o wide
        ;;
    pods)
        kubectl get pods --all-namespaces -o wide
        ;;
    services)
        kubectl get services --all-namespaces
        ;;
    deployments)
        kubectl get deployments --all-namespaces
        ;;
    logs)
        if [[ -z "$2" ]]; then
            echo "Usage: k8s-manager logs <pod-name> [namespace]"
            exit 1
        fi
        namespace="${3:-default}"
        kubectl logs -f "$2" -n "$namespace"
        ;;
    exec)
        if [[ -z "$2" ]]; then
            echo "Usage: k8s-manager exec <pod-name> [namespace] [container]"
            exit 1
        fi
        namespace="${3:-default}"
        container="${4:-}"
        if [[ -n "$container" ]]; then
            kubectl exec -it "$2" -n "$namespace" -c "$container" -- /bin/bash
        else
            kubectl exec -it "$2" -n "$namespace" -- /bin/bash
        fi
        ;;
    port-forward)
        if [[ -z "$2" ]] || [[ -z "$3" ]]; then
            echo "Usage: k8s-manager port-forward <service-name> <local-port>:<remote-port> [namespace]"
            exit 1
        fi
        namespace="${4:-default}"
        kubectl port-forward -n "$namespace" service/"$2" "$3"
        ;;
    describe)
        if [[ -z "$2" ]] || [[ -z "$3" ]]; then
            echo "Usage: k8s-manager describe <resource-type> <resource-name> [namespace]"
            exit 1
        fi
        namespace="${4:-default}"
        kubectl describe "$2" "$3" -n "$namespace"
        ;;
    top)
        kubectl top nodes
        echo
        kubectl top pods --all-namespaces
        ;;
    events)
        kubectl get events --all-namespaces --sort-by='.lastTimestamp'
        ;;
    *)
        echo "Usage: k8s-manager [nodes|pods|services|deployments|logs|exec|port-forward|describe|top|events] [options]"
        echo "Commands:"
        echo "  nodes        - List all nodes"
        echo "  pods         - List all pods"
        echo "  services     - List all services"
        echo "  deployments  - List all deployments"
        echo "  logs <pod>   - Show pod logs"
        echo "  exec <pod>   - Execute into pod"
        echo "  port-forward - Port forward service"
        echo "  describe     - Describe resource"
        echo "  top          - Show resource usage"
        echo "  events       - Show cluster events"
        ;;
esac
EOF

    chmod +x /usr/local/bin/k8s-manager
    
    # Create Kubernetes health check script
    cat > /usr/local/bin/k8s-health << 'EOF'
#!/bin/bash

# Kubernetes Health Check Script

echo "=== Kubernetes Health Check ==="
echo

echo "1. kubectl version:"
kubectl version --client
echo

echo "2. kubeadm version:"
kubeadm version
echo

echo "3. kubelet status:"
systemctl is-active kubelet
echo

echo "4. containerd status:"
systemctl is-active containerd
echo

echo "5. Cluster nodes:"
kubectl get nodes 2>/dev/null || echo "No cluster available"
echo

echo "6. Cluster pods:"
kubectl get pods --all-namespaces 2>/dev/null || echo "No cluster available"
echo

echo "7. Cluster services:"
kubectl get services --all-namespaces 2>/dev/null || echo "No cluster available"
echo

echo "8. Helm version:"
helm version 2>/dev/null || echo "Helm not available"
echo

echo "9. Installed tools:"
echo "kubectl: $(which kubectl 2>/dev/null || echo 'Not found')"
echo "kubeadm: $(which kubeadm 2>/dev/null || echo 'Not found')"
echo "kubelet: $(which kubelet 2>/dev/null || echo 'Not found')"
echo "helm: $(which helm 2>/dev/null || echo 'Not found')"
echo "k9s: $(which k9s 2>/dev/null || echo 'Not found')"
echo "kubectx: $(which kubectx 2>/dev/null || echo 'Not found')"
echo "stern: $(which stern 2>/dev/null || echo 'Not found')"
EOF

    chmod +x /usr/local/bin/k8s-health
    
    log_success "Helper scripts created"
}

# Configure system for Kubernetes
configure_system() {
    log_step "Configuring system for Kubernetes..."
    
    # Disable swap
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    # Load required kernel modules
    cat > /etc/modules-load.d/k8s.conf << 'EOF'
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter
    
    # Configure sysctl parameters
    cat > /etc/sysctl.d/k8s.conf << 'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sysctl --system
    
    log_success "System configured for Kubernetes"
}

# Test Kubernetes tools installation
test_kubernetes_tools() {
    log_step "Testing Kubernetes tools installation..."
    
    # Test kubectl
    if ! kubectl version --client > /dev/null 2>&1; then
        log_error "kubectl test failed"
        return 1
    fi
    
    # Test kubeadm
    if ! kubeadm version > /dev/null 2>&1; then
        log_error "kubeadm test failed"
        return 1
    fi
    
    # Test kubelet
    if ! systemctl is-active --quiet kubelet; then
        log_error "kubelet service is not running"
        return 1
    fi
    
    # Test containerd
    if ! systemctl is-active --quiet containerd; then
        log_error "containerd service is not running"
        return 1
    fi
    
    # Test Helm
    if ! helm version > /dev/null 2>&1; then
        log_error "Helm test failed"
        return 1
    fi
    
    log_success "Kubernetes tools installation test passed"
}

# Main execution
main() {
    log_step "Starting Kubernetes tools setup..."
    
    check_root
    install_kubectl
    install_kubeadm
    install_containerd
    install_helm
    install_k9s
    install_kubectx
    install_kubectl_plugins
    install_additional_tools
    configure_kubectl
    configure_system
    create_helper_scripts
    test_kubernetes_tools
    
    log_success "Kubernetes tools setup completed successfully!"
    log_info "You can now use kubectl, kubeadm, and other Kubernetes tools"
    log_info "Helper scripts available: k8s-manager, k8s-health"
    log_info "To initialize a cluster: kubeadm init"
}

# Run main function
main "$@"

