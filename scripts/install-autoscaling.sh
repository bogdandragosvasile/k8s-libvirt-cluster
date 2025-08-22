#!/bin/bash

# Master Autoscaling Installation Script
# This script installs all autoscaling components for the Kubernetes cluster

set -e

echo "🚀 Installing Complete Autoscaling Solution..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Function to check cluster connectivity
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Function to wait for component to be ready
wait_for_component() {
    local namespace=$1
    local label_selector=$2
    local component_name=$3
    
    print_status "Waiting for $component_name to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get pods -n $namespace -l $label_selector --no-headers | grep -q "Running"; then
            print_status "✅ $component_name is ready!"
            return 0
        fi
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_error "❌ $component_name failed to become ready within timeout"
    return 1
}

# Main installation process
main() {
    print_header "Starting Complete Autoscaling Installation"
    
    # Check prerequisites
    check_kubectl
    check_cluster
    
    print_status "Cluster connectivity verified"
    
    # Step 1: Install HPA and Metrics Server
    print_header "Step 1: Installing HPA and Metrics Server"
    if [ -f "./scripts/install-hpa.sh" ]; then
        print_status "Running HPA installation script..."
        ./scripts/install-hpa.sh
    else
        print_error "HPA installation script not found"
        exit 1
    fi
    
    # Wait for metrics server
    wait_for_component "kube-system" "k8s-app=metrics-server" "Metrics Server"
    
    # Step 2: Install Cluster Autoscaler
    print_header "Step 2: Installing Cluster Autoscaler"
    if [ -f "./scripts/install-cluster-autoscaler.sh" ]; then
        print_status "Running Cluster Autoscaler installation script..."
        ./scripts/install-cluster-autoscaler.sh
    else
        print_error "Cluster Autoscaler installation script not found"
        exit 1
    fi
    
    # Wait for cluster autoscaler
    wait_for_component "cluster-autoscaler" "app=cluster-autoscaler" "Cluster Autoscaler"
    
    # Step 3: Verify installation
    print_header "Step 3: Verifying Installation"
    
    print_status "Checking Metrics Server..."
    if kubectl top nodes &> /dev/null; then
        print_status "✅ Metrics Server is working"
    else
        print_warning "⚠️  Metrics Server might need more time to start"
    fi
    
    print_status "Checking HPA components..."
    kubectl get hpa -A 2>/dev/null || print_warning "No HPA found yet"
    
    print_status "Checking Cluster Autoscaler..."
    kubectl get pods -n cluster-autoscaler 2>/dev/null || print_error "Cluster Autoscaler not found"
    
    # Step 4: Create additional test workloads
    print_header "Step 4: Creating Additional Test Workloads"
    
    print_status "Creating stress test workload..."
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-test
  namespace: hpa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stress-test
  template:
    metadata:
      labels:
        app: stress-test
    spec:
      containers:
      - name: stress
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Stress test running'; dd if=/dev/zero of=/dev/null bs=1M count=100; sleep 5; done"]
        resources:
          requests:
            memory: "200Mi"
            cpu: "200m"
          limits:
            memory: "400Mi"
            cpu: "400m"
EOF
    
    print_status "Creating HPA for stress test..."
    cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: stress-test-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: stress-test
  minReplicas: 1
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
EOF
    
    # Step 5: Display final status and instructions
    print_header "Step 5: Installation Complete"
    
    print_status "✅ All autoscaling components installed successfully!"
    
    echo ""
    print_status "📊 Available Commands:"
    echo "   kubectl get hpa -A                    # View all HPAs"
    echo "   kubectl top nodes                     # View node resource usage"
    echo "   kubectl top pods -A                   # View pod resource usage"
    echo "   kubectl get pods -n cluster-autoscaler # Check cluster autoscaler"
    echo "   kubectl logs -f deployment/cluster-autoscaler -n cluster-autoscaler"
    
    echo ""
    print_status "🧪 Test Autoscaling:"
    echo "   # Test HPA scaling"
    echo "   kubectl scale deployment autoscaling-test --replicas=5 -n hpa-demo"
    echo "   kubectl scale deployment stress-test --replicas=3 -n hpa-demo"
    echo ""
    echo "   # Monitor scaling"
    echo "   watch kubectl get pods -n hpa-demo"
    echo "   watch kubectl get hpa -n hpa-demo"
    echo "   watch kubectl top pods -n hpa-demo"
    
    echo ""
    print_status "🔧 Manual Scaling Operations:"
    echo "   ./scripts/autoscaling-manager.sh status     # Check status"
    echo "   ./scripts/autoscaling-manager.sh scale-up 2  # Add 2 nodes"
    echo "   ./scripts/autoscaling-manager.sh scale-down 1 # Remove 1 node"
    
    echo ""
    print_status "📈 Monitor Scaling Events:"
    echo "   kubectl get events --sort-by='.lastTimestamp' | grep -i scale"
    echo "   kubectl describe hpa -A"
    
    echo ""
    print_warning "⚠️  Important Notes:"
    echo "   - Cluster autoscaler requires additional worker nodes to be available"
    echo "   - HPA works with the metrics server for resource-based scaling"
    echo "   - Scaling policies can be customized in the HPA configurations"
    echo "   - Monitor resource usage to ensure optimal scaling behavior"
    
    echo ""
    print_status "🎉 Autoscaling is now ready for your Kubernetes cluster!"
}

# Run main function
main "$@"
