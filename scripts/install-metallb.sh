#!/bin/bash

# =============================================================================
# Enhanced MetalLB Installation Script
# =============================================================================
# Supports both NAT and Bridge network modes with dynamic IP range detection

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Configuration (can be overridden by environment variables)
METALLB_VERSION="${METALLB_VERSION:-v0.15.2}"
METALLB_IP_RANGE="${METALLB_IP_RANGE:-}"
NETWORK_MODE="${NETWORK_MODE:-auto}"
SKIP_TEST_SERVICE="${SKIP_TEST_SERVICE:-false}"

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
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
# Network Detection and Configuration
# =============================================================================

detect_network_mode() {
    log "Detecting network configuration..."
    
    # Get node IPs to determine network range
    local node_ips=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    local first_ip=$(echo $node_ips | awk '{print $1}')
    
    if [[ -z "$first_ip" ]]; then
        error "Could not detect node IP addresses"
    fi
    
    log "First node IP: $first_ip"
    
    # Determine network range based on IP
    if [[ "$first_ip" =~ ^192\.168\.122\. ]]; then
        DETECTED_NETWORK="nat"
        DEFAULT_IP_RANGE="192.168.122.240-192.168.122.250"
        log "Detected NAT network mode (192.168.122.x)"
    elif [[ "$first_ip" =~ ^192\.168\.1\. ]]; then
        DETECTED_NETWORK="bridge"
        DEFAULT_IP_RANGE="192.168.1.240-192.168.1.250"
        log "Detected Bridge network mode (192.168.1.x)"
    elif [[ "$first_ip" =~ ^10\. ]]; then
        DETECTED_NETWORK="bridge"
        # Extract network and create range
        local network_base=$(echo $first_ip | cut -d. -f1-3)
        DEFAULT_IP_RANGE="${network_base}.240-${network_base}.250"
        log "Detected Bridge network mode (${network_base}.x)"
    elif [[ "$first_ip" =~ ^172\. ]]; then
        DETECTED_NETWORK="bridge"
        local network_base=$(echo $first_ip | cut -d. -f1-3)
        DEFAULT_IP_RANGE="${network_base}.240-${network_base}.250"
        log "Detected Bridge network mode (${network_base}.x)"
    else
        warn "Unknown network range for IP $first_ip, using default NAT range"
        DETECTED_NETWORK="unknown"
        DEFAULT_IP_RANGE="192.168.122.240-192.168.122.250"
    fi
    
    # Use provided range or detected default
    if [[ -n "$METALLB_IP_RANGE" ]]; then
        IP_RANGE="$METALLB_IP_RANGE"
        log "Using provided IP range: $IP_RANGE"
    else
        IP_RANGE="$DEFAULT_IP_RANGE"
        log "Using detected IP range: $IP_RANGE"
    fi
}

# =============================================================================
# MetalLB Installation Functions
# =============================================================================

install_metallb() {
    log "Installing MetalLB $METALLB_VERSION..."
    
    # Enable strict ARP mode for IPVS
    log "Enabling strict ARP mode for kube-proxy..."
    kubectl get configmap kube-proxy -n kube-system -o yaml | \
      sed -e 's/strictARP: false/strictARP: true/' | \
      kubectl apply -f - -n kube-system || warn "Failed to update kube-proxy config"

    # Install MetalLB
    log "Applying MetalLB manifests..."
    kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"

    # Wait for MetalLB components to be ready
    log "Waiting for MetalLB components to be ready..."
    kubectl wait --namespace metallb-system \
      --for=condition=ready pod \
      --selector=app=metallb \
      --timeout=300s || error "MetalLB pods failed to become ready"

    success "MetalLB installation completed"
}

configure_metallb() {
    log "Configuring MetalLB with IP range: $IP_RANGE"
    
    # Create IP Address Pool
    log "Creating MetalLB IP Address Pool..."
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $IP_RANGE
  autoAssign: true
EOF

    # Create L2 Advertisement
    log "Creating MetalLB L2 Advertisement..."
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

    success "MetalLB configuration completed"
}

verify_metallb() {
    log "Verifying MetalLB installation..."
    
    echo "=== MetalLB Pods ==="
    kubectl get pods -n metallb-system
    
    echo ""
    echo "=== IP Address Pools ==="
    kubectl get ipaddresspool -n metallb-system
    
    echo ""
    echo "=== L2 Advertisements ==="
    kubectl get l2advertisement -n metallb-system
    
    success "MetalLB verification completed"
}

create_test_service() {
    if [[ "$SKIP_TEST_SERVICE" == "true" ]]; then
        log "Skipping test service creation"
        return 0
    fi
    
    log "Creating test LoadBalancer service..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-metallb-test
  labels:
    app: nginx-metallb-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-metallb-test
  template:
    metadata:
      labels:
        app: nginx-metallb-test
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-metallb-test
  labels:
    app: nginx-metallb-test
spec:
  type: LoadBalancer
  selector:
    app: nginx-metallb-test
  ports:
  - port: 80
    targetPort: 80
    name: http
EOF

    # Wait for external IP assignment
    log "Waiting for external IP assignment..."
    local max_attempts=20
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local external_ip=$(kubectl get svc nginx-metallb-test -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '')
        
        if [[ -n "$external_ip" && "$external_ip" != "null" ]]; then
            success "External IP assigned: $external_ip"
            
            # Test connectivity
            log "Testing service connectivity..."
            if curl -f "http://$external_ip" --max-time 10 >/dev/null 2>&1; then
                success "✅ Service is accessible at http://$external_ip"
            else
                warn "⚠️ Service IP assigned but not yet accessible"
            fi
            break
        fi
        
        log "Waiting for external IP... (attempt $attempt/$max_attempts)"
        sleep 15
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        warn "External IP not assigned within timeout period"
    fi
    
    # Show final status
    echo ""
    echo "=== Test Service Status ==="
    kubectl get svc nginx-metallb-test
    kubectl get deployment nginx-metallb-test
}

cleanup_test_service() {
    log "Cleaning up test service..."
    kubectl delete deployment nginx-metallb-test --ignore-not-found=true
    kubectl delete service nginx-metallb-test --ignore-not-found=true
    success "Test service cleanup completed"
}

# =============================================================================
# Main Execution
# =============================================================================

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Install and configure MetalLB for Kubernetes load balancing.

OPTIONS:
    --ip-range RANGE     Specify MetalLB IP range (e.g., 192.168.1.240-192.168.1.250)
    --network-mode MODE  Set network mode: nat, bridge, or auto (default: auto)
    --skip-test          Skip creating test service
    --cleanup-test       Remove existing test service and exit
    --version VERSION    MetalLB version to install (default: v0.15.2)
    --help              Show this help message

EXAMPLES:
    $0                                    # Auto-detect network and install
    $0 --ip-range 10.0.1.240-10.0.1.250  # Use custom IP range
    $0 --network-mode bridge              # Force bridge mode
    $0 --cleanup-test                     # Remove test service

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ip-range)
                METALLB_IP_RANGE="$2"
                shift 2
                ;;
            --network-mode)
                NETWORK_MODE="$2"
                shift 2
                ;;
            --skip-test)
                SKIP_TEST_SERVICE="true"
                shift
                ;;
            --cleanup-test)
                cleanup_test_service
                exit 0
                ;;
            --version)
                METALLB_VERSION="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

main() {
    log "Starting enhanced MetalLB installation..."
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check kubectl connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    fi
    
    # Detect network configuration
    detect_network_mode
    
    # Install and configure MetalLB
    install_metallb
    configure_metallb
    verify_metallb
    
    # Create test service
    create_test_service
    
    success "🎉 MetalLB installation and configuration complete!"
    log "IP Range: $IP_RANGE"
    log "Network Mode: $DETECTED_NETWORK"
    
    if [[ "$SKIP_TEST_SERVICE" != "true" ]]; then
        echo ""
        log "Test service created. You can clean it up later with: $0 --cleanup-test"
    fi
}

# Run main function with all arguments
main "$@"
