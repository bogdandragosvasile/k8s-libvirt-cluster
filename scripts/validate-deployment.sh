#!/bin/bash

# =============================================================================
# Kubernetes Cluster Deployment Validation Script
# =============================================================================
# Comprehensive validation of multi-distro, network-flexible k8s deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VALIDATION_RESULTS_FILE="/tmp/k8s-cluster-validation-$(date +%Y%m%d-%H%M%S).log"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$VALIDATION_RESULTS_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$VALIDATION_RESULTS_FILE"
    ((WARNINGS++))
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$VALIDATION_RESULTS_FILE"
    ((FAILED_TESTS++))
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$VALIDATION_RESULTS_FILE"
    ((PASSED_TESTS++))
}

test_start() {
    ((TOTAL_TESTS++))
    log "Test $TOTAL_TESTS: $1"
}

# =============================================================================
# Infrastructure Validation Tests
# =============================================================================

validate_terraform_state() {
    test_start "Terraform state validation"
    
    if [[ ! -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        error "Terraform state file not found"
        return 1
    fi
    
    cd "$PROJECT_ROOT/terraform"
    
    if terraform validate >/dev/null 2>&1; then
        success "Terraform configuration is valid"
    else
        error "Terraform configuration validation failed"
        return 1
    fi
    
    if terraform show >/dev/null 2>&1; then
        success "Terraform state is accessible"
    else
        error "Cannot read Terraform state"
        return 1
    fi
    
    # Check outputs
    local outputs=$(terraform output -json 2>/dev/null)
    if [[ -n "$outputs" ]]; then
        success "Terraform outputs are available"
        echo "$outputs" | jq . >> "$VALIDATION_RESULTS_FILE"
    else
        error "No Terraform outputs found"
        return 1
    fi
}

validate_vm_infrastructure() {
    test_start "VM infrastructure validation"
    
    # Check if VMs are running
    local expected_vms=("loadbalancer1" "loadbalancer2" "kcontrolplane1" "kcontrolplane2" "kcontrolplane3" "kworker1" "kworker2" "kworker3")
    local running_vms=$(virsh list --name 2>/dev/null || echo "")
    
    for vm in "${expected_vms[@]}"; do
        if echo "$running_vms" | grep -q "^$vm$"; then
            success "VM $vm is running"
        else
            error "VM $vm is not running"
        fi
    done
    
    # Check VM resources
    for vm in "${expected_vms[@]}"; do
        if virsh dominfo "$vm" >/dev/null 2>&1; then
            local memory=$(virsh dominfo "$vm" | grep "Max memory" | awk '{print $3}')
            local vcpus=$(virsh dominfo "$vm" | grep "CPU(s)" | awk '{print $2}')
            log "VM $vm: ${memory} KB memory, ${vcpus} vCPUs"
        else
            warn "Cannot get info for VM $vm"
        fi
    done
}

validate_network_connectivity() {
    test_start "Network connectivity validation"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    
    if [[ -z "$outputs" ]]; then
        error "Cannot get VM IPs from Terraform outputs"
        return 1
    fi
    
    # Extract VM IPs
    local vm_ips=$(echo "$outputs" | jq -r '.vm_ips.value | to_entries[] | "\(.key)=\(.value)"')
    
    while IFS='=' read -r vm_name vm_ip; do
        if ping -c 2 -W 3 "$vm_ip" >/dev/null 2>&1; then
            success "VM $vm_name ($vm_ip) is reachable"
        else
            error "VM $vm_name ($vm_ip) is not reachable"
        fi
    done <<< "$vm_ips"
}

# =============================================================================
# Kubernetes Cluster Validation Tests
# =============================================================================

validate_cluster_connectivity() {
    test_start "Kubernetes cluster connectivity"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    
    if [[ -z "$control_plane_ip" || "$control_plane_ip" == "null" ]]; then
        error "Cannot get control plane IP"
        return 1
    fi
    
    # Test SSH connectivity
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "echo 'SSH OK'" >/dev/null 2>&1; then
        success "SSH connectivity to control plane established"
    else
        error "Cannot establish SSH connection to control plane"
        return 1
    fi
    
    # Test kubectl connectivity
    if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl cluster-info" >/dev/null 2>&1; then
        success "kubectl connectivity to cluster established"
    else
        error "kubectl cannot connect to cluster"
        return 1
    fi
}

validate_cluster_nodes() {
    test_start "Kubernetes cluster nodes validation"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    
    # Get node status
    local node_status=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get nodes --no-headers" 2>/dev/null)
    
    if [[ -z "$node_status" ]]; then
        error "Cannot get node status"
        return 1
    fi
    
    # Check each node
    echo "$node_status" | while read -r node status role age version; do
        if [[ "$status" == "Ready" ]]; then
            success "Node $node is Ready"
        else
            error "Node $node status: $status"
        fi
    done
    
    # Count nodes
    local total_nodes=$(echo "$node_status" | wc -l)
    local ready_nodes=$(echo "$node_status" | grep -c "Ready" || echo "0")
    
    log "Cluster status: $ready_nodes/$total_nodes nodes ready"
    
    if [[ "$ready_nodes" -eq "$total_nodes" && "$total_nodes" -ge 6 ]]; then
        success "All expected nodes are ready"
    else
        error "Not all nodes are ready ($ready_nodes/$total_nodes)"
    fi
}

validate_system_pods() {
    test_start "System pods validation"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    
    # Check system pods in kube-system namespace
    local system_pods=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get pods -n kube-system --no-headers" 2>/dev/null)
    
    if [[ -z "$system_pods" ]]; then
        error "Cannot get system pods status"
        return 1
    fi
    
    # Critical system components
    local critical_components=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd" "kube-proxy" "calico")
    
    for component in "${critical_components[@]}"; do
        if echo "$system_pods" | grep -q "$component"; then
            local pod_status=$(echo "$system_pods" | grep "$component" | head -1 | awk '{print $3}')
            if [[ "$pod_status" == "Running" ]]; then
                success "System component $component is running"
            else
                error "System component $component status: $pod_status"
            fi
        else
            warn "System component $component not found"
        fi
    done
    
    # Count running system pods
    local total_pods=$(echo "$system_pods" | wc -l)
    local running_pods=$(echo "$system_pods" | grep -c "Running" || echo "0")
    
    log "System pods: $running_pods/$total_pods running"
}

# =============================================================================
# Service Validation Tests
# =============================================================================

validate_metallb() {
    test_start "MetalLB validation"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    
    # Check if MetalLB namespace exists
    if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get namespace metallb-system" >/dev/null 2>&1; then
        success "MetalLB namespace exists"
    else
        warn "MetalLB namespace not found - MetalLB not installed"
        return 0
    fi
    
    # Check MetalLB pods
    local metallb_pods=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get pods -n metallb-system --no-headers" 2>/dev/null)
    
    if [[ -n "$metallb_pods" ]]; then
        local running_count=$(echo "$metallb_pods" | grep -c "Running" || echo "0")
        local total_count=$(echo "$metallb_pods" | wc -l)
        
        if [[ "$running_count" -eq "$total_count" ]]; then
            success "All MetalLB pods are running ($running_count/$total_count)"
        else
            error "Some MetalLB pods are not running ($running_count/$total_count)"
        fi
    else
        error "No MetalLB pods found"
    fi
    
    # Check IP address pool
    if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get ipaddresspool -n metallb-system" >/dev/null 2>&1; then
        success "MetalLB IP address pool configured"
    else
        error "MetalLB IP address pool not found"
    fi
    
    # Test LoadBalancer service
    local lb_services=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get svc --all-namespaces -o wide | grep LoadBalancer" 2>/dev/null || echo "")
    
    if [[ -n "$lb_services" ]]; then
        local services_with_ip=$(echo "$lb_services" | grep -v "<pending>" | wc -l)
        local total_lb_services=$(echo "$lb_services" | wc -l)
        
        if [[ "$services_with_ip" -gt 0 ]]; then
            success "LoadBalancer services have external IPs ($services_with_ip/$total_lb_services)"
        else
            warn "LoadBalancer services found but no external IPs assigned"
        fi
    else
        log "No LoadBalancer services found (this is normal if not created yet)"
    fi
}

validate_ingress_controller() {
    test_start "Nginx Ingress Controller validation"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    
    # Check if ingress-nginx namespace exists
    if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get namespace ingress-nginx" >/dev/null 2>&1; then
        success "Nginx Ingress Controller namespace exists"
    else
        warn "Nginx Ingress Controller namespace not found - not installed"
        return 0
    fi
    
    # Check ingress controller pods
    local ingress_pods=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get pods -n ingress-nginx --no-headers" 2>/dev/null)
    
    if [[ -n "$ingress_pods" ]]; then
        local running_count=$(echo "$ingress_pods" | grep -c "Running" || echo "0")
        local total_count=$(echo "$ingress_pods" | wc -l)
        
        if [[ "$running_count" -eq "$total_count" ]]; then
            success "All Nginx Ingress Controller pods are running ($running_count/$total_count)"
        else
            error "Some Nginx Ingress Controller pods are not running ($running_count/$total_count)"
        fi
    else
        error "No Nginx Ingress Controller pods found"
    fi
    
    # Check ingress service
    local ingress_service=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get svc -n ingress-nginx --no-headers" 2>/dev/null | grep LoadBalancer || echo "")
    
    if [[ -n "$ingress_service" ]]; then
        success "Nginx Ingress Controller LoadBalancer service found"
    else
        warn "Nginx Ingress Controller LoadBalancer service not found"
    fi
}

validate_cert_manager() {
    test_start "Cert-Manager validation"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    
    # Check if cert-manager namespace exists
    if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get namespace cert-manager" >/dev/null 2>&1; then
        success "Cert-Manager namespace exists"
    else
        warn "Cert-Manager namespace not found - not installed"
        return 0
    fi
    
    # Check cert-manager pods
    local certmgr_pods=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get pods -n cert-manager --no-headers" 2>/dev/null)
    
    if [[ -n "$certmgr_pods" ]]; then
        local running_count=$(echo "$certmgr_pods" | grep -c "Running" || echo "0")
        local total_count=$(echo "$certmgr_pods" | wc -l)
        
        if [[ "$running_count" -eq "$total_count" ]]; then
            success "All Cert-Manager pods are running ($running_count/$total_count)"
        else
            error "Some Cert-Manager pods are not running ($running_count/$total_count)"
        fi
    else
        error "No Cert-Manager pods found"
    fi
    
    # Check ClusterIssuers
    local cluster_issuers=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get clusterissuers --no-headers" 2>/dev/null || echo "")
    
    if [[ -n "$cluster_issuers" ]]; then
        local issuer_count=$(echo "$cluster_issuers" | wc -l)
        success "ClusterIssuers configured ($issuer_count found)"
        
        # Check issuer status
        echo "$cluster_issuers" | while read -r issuer ready status age; do
            if [[ "$ready" == "True" ]]; then
                success "ClusterIssuer $issuer is ready"
            else
                warn "ClusterIssuer $issuer status: $ready"
            fi
        done
    else
        log "No ClusterIssuers found (normal if Let's Encrypt not configured)"
    fi
}

# =============================================================================
# Distribution-Specific Validation
# =============================================================================

validate_distribution_compatibility() {
    test_start "Distribution compatibility validation"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    local distro_name=$(echo "$outputs" | jq -r '.distro_info.value.name')
    local package_mgr=$(echo "$outputs" | jq -r '.distro_info.value.package_mgr')
    
    log "Validating distribution: $distro_name"
    log "Package manager: $package_mgr"
    log "Default user: $ssh_user"
    
    # Check OS version on control plane
    local os_info=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "cat /etc/os-release" 2>/dev/null)
    
    if [[ -n "$os_info" ]]; then
        success "OS information retrieved successfully"
        echo "$os_info" | grep -E "(NAME|VERSION)" >> "$VALIDATION_RESULTS_FILE"
    else
        error "Cannot retrieve OS information"
    fi
    
    # Check package manager
    case "$package_mgr" in
        apt)
            if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "which apt-get" >/dev/null 2>&1; then
                success "Package manager apt-get is available"
            else
                error "Package manager apt-get not found"
            fi
            ;;
        dnf)
            if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "which dnf" >/dev/null 2>&1; then
                success "Package manager dnf is available"
            else
                error "Package manager dnf not found"
            fi
            ;;
        yum)
            if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "which yum" >/dev/null 2>&1; then
                success "Package manager yum is available"
            else
                error "Package manager yum not found"
            fi
            ;;
        zypper)
            if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "which zypper" >/dev/null 2>&1; then
                success "Package manager zypper is available"
            else
                error "Package manager zypper not found"
            fi
            ;;
        *)
            warn "Unknown package manager: $package_mgr"
            ;;
    esac
}

# =============================================================================
# Performance and Resource Validation
# =============================================================================

validate_resource_utilization() {
    test_start "Resource utilization validation"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    
    # Check CPU and memory usage
    local cpu_usage=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | sed 's/%us,//'" 2>/dev/null)
    local memory_info=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "free -h | grep Mem" 2>/dev/null)
    
    if [[ -n "$cpu_usage" ]]; then
        log "CPU usage: ${cpu_usage}%"
        if (( $(echo "$cpu_usage < 80.0" | bc -l) )); then
            success "CPU usage is within acceptable limits"
        else
            warn "High CPU usage detected: ${cpu_usage}%"
        fi
    else
        warn "Cannot retrieve CPU usage information"
    fi
    
    if [[ -n "$memory_info" ]]; then
        log "Memory info: $memory_info"
        success "Memory information retrieved"
    else
        warn "Cannot retrieve memory information"
    fi
    
    # Check disk usage
    local disk_usage=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" 2>/dev/null)
    
    if [[ -n "$disk_usage" ]]; then
        log "Root filesystem usage: ${disk_usage}%"
        if [[ "$disk_usage" -lt 80 ]]; then
            success "Disk usage is within acceptable limits"
        else
            warn "High disk usage detected: ${disk_usage}%"
        fi
    else
        warn "Cannot retrieve disk usage information"
    fi
}

# =============================================================================
# End-to-End Integration Tests
# =============================================================================

run_integration_tests() {
    test_start "End-to-end integration tests"
    
    cd "$PROJECT_ROOT/terraform"
    local outputs=$(terraform output -json 2>/dev/null)
    local control_plane_ip=$(echo "$outputs" | jq -r '.cluster_access.value.control_plane_ip')
    local ssh_user=$(echo "$outputs" | jq -r '.distro_info.value.user')
    
    # Test 1: Deploy a simple application
    log "Deploying test application..."
    local test_deployment=$(cat <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: validation-test-app
  labels:
    app: validation-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: validation-test
  template:
    metadata:
      labels:
        app: validation-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
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
  name: validation-test-service
spec:
  selector:
    app: validation-test
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
)
    
    if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "echo '$test_deployment' | kubectl apply -f -" >/dev/null 2>&1; then
        success "Test application deployed successfully"
        
        # Wait for deployment to be ready
        sleep 30
        
        # Check if pods are running
        local pod_status=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get pods -l app=validation-test --no-headers" 2>/dev/null)
        local running_pods=$(echo "$pod_status" | grep -c "Running" || echo "0")
        
        if [[ "$running_pods" -eq 2 ]]; then
            success "All test application pods are running"
        else
            error "Test application pods not all running ($running_pods/2)"
        fi
        
        # Test service connectivity
        if ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl get svc validation-test-service" >/dev/null 2>&1; then
            success "Test service is accessible"
        else
            error "Test service is not accessible"
        fi
        
        # Cleanup test resources
        ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl delete deployment validation-test-app" >/dev/null 2>&1
        ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s-cluster "$ssh_user@$control_plane_ip" "kubectl delete service validation-test-service" >/dev/null 2>&1
        log "Test resources cleaned up"
        
    else
        error "Failed to deploy test application"
    fi
}

# =============================================================================
# Report Generation
# =============================================================================

generate_report() {
    log "Generating validation report..."
    
    cat << EOF >> "$VALIDATION_RESULTS_FILE"

========================================================
KUBERNETES CLUSTER VALIDATION REPORT
========================================================
Validation Date: $(date)
Validation Script: $0

SUMMARY:
  Total Tests: $TOTAL_TESTS
  Passed: $PASSED_TESTS
  Failed: $FAILED_TESTS
  Warnings: $WARNINGS

OVERALL STATUS: $(if [[ $FAILED_TESTS -eq 0 ]]; then echo "PASS"; else echo "FAIL"; fi)

========================================================
EOF

    echo
    echo "=========================================================="
    echo "🔍 KUBERNETES CLUSTER VALIDATION SUMMARY"
    echo "=========================================================="
    echo "📊 Test Results:"
    echo "   Total Tests: $TOTAL_TESTS"
    echo "   ✅ Passed: $PASSED_TESTS"
    echo "   ❌ Failed: $FAILED_TESTS"
    echo "   ⚠️ Warnings: $WARNINGS"
    echo
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 OVERALL STATUS: VALIDATION PASSED${NC}"
        echo "✅ Your Kubernetes cluster deployment is working correctly!"
    else
        echo -e "${RED}❌ OVERALL STATUS: VALIDATION FAILED${NC}"
        echo "⚠️ Please review the failed tests and fix the issues."
    fi
    
    echo
    echo "📋 Detailed results saved to: $VALIDATION_RESULTS_FILE"
    echo "=========================================================="
}

# =============================================================================
# Main Execution
# =============================================================================

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Comprehensive validation of Kubernetes cluster deployment.

OPTIONS:
    --quick              Run only basic validation tests
    --infrastructure     Test only infrastructure components
    --services          Test only Kubernetes services  
    --integration       Run only integration tests
    --skip-ssh-check    Skip SSH connectivity tests
    --report-only       Generate report from existing log
    --help              Show this help message

EXAMPLES:
    $0                  # Run all validation tests
    $0 --quick          # Run basic tests only
    $0 --services       # Test services only
    $0 --infrastructure # Test infrastructure only

EOF
}

main() {
    echo "🔍 Starting Kubernetes Cluster Validation..."
    echo "Validation started at $(date)" > "$VALIDATION_RESULTS_FILE"
    echo
    
    # Parse command line arguments
    local quick_mode=false
    local infra_only=false
    local services_only=false
    local integration_only=false
    local skip_ssh=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                quick_mode=true
                shift
                ;;
            --infrastructure)
                infra_only=true
                shift
                ;;
            --services)
                services_only=true
                shift
                ;;
            --integration)
                integration_only=true
                shift
                ;;
            --skip-ssh-check)
                skip_ssh=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    if ! command -v kubectl >/dev/null 2>&1; then
        error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v ssh >/dev/null 2>&1; then
        error "ssh not found. Please install SSH client."
        exit 1
    fi
    
    if [[ ! -f ~/.ssh/k8s-cluster ]]; then
        error "SSH key ~/.ssh/k8s-cluster not found. Please ensure SSH keys are properly configured."
        exit 1
    fi
    
    # Run validation tests based on mode
    if [[ "$infra_only" == "true" ]]; then
        log "Running infrastructure validation only..."
        validate_terraform_state
        validate_vm_infrastructure
        validate_network_connectivity
    elif [[ "$services_only" == "true" ]]; then
        log "Running services validation only..."
        validate_metallb
        validate_ingress_controller
        validate_cert_manager
    elif [[ "$integration_only" == "true" ]]; then
        log "Running integration tests only..."
        run_integration_tests
    elif [[ "$quick_mode" == "true" ]]; then
        log "Running quick validation..."
        validate_terraform_state
        validate_cluster_connectivity
        validate_cluster_nodes
    else
        log "Running comprehensive validation..."
        
        # Infrastructure tests
        validate_terraform_state
        validate_vm_infrastructure
        validate_network_connectivity
        
        # Kubernetes tests
        validate_cluster_connectivity
        validate_cluster_nodes
        validate_system_pods
        
        # Service tests
        validate_metallb
        validate_ingress_controller
        validate_cert_manager
        
        # Distribution tests
        validate_distribution_compatibility
        
        # Performance tests
        validate_resource_utilization
        
        # Integration tests
        run_integration_tests
    fi
    
    # Generate final report
    generate_report
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function with all arguments
main "$@"
