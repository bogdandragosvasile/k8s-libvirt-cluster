#!/bin/bash

# Autoscaling Manager Script
# This script manages the autoscaling operations for the Kubernetes cluster

set -e

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

# Configuration
AUTOSCALING_NODES=(
    "kworker4:192.168.122.204"
    "kworker5:192.168.122.205"
    "kworker6:192.168.122.206"
    "kworker7:192.168.122.207"
    "kworker8:192.168.122.208"
    "kworker9:192.168.122.209"
    "kworker10:192.168.122.210"
)

SSH_USER="ubuntu"
SSH_KEY="~/.ssh/k8s-cluster"
CONTROL_PLANE_IP="192.168.122.101"

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

# Function to get join command from control plane
get_join_command() {
    print_status "Getting join command from control plane..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$CONTROL_PLANE_IP "sudo kubeadm token create --print-join-command"
}

# Function to start a worker node
start_worker_node() {
    local node_name=$1
    local node_ip=$2
    
    print_status "Starting worker node: $node_name ($node_ip)"
    
    # Start the VM
    virsh start $node_name
    
    # Wait for VM to be running
    print_status "Waiting for VM to start..."
    while ! virsh domstate $node_name | grep -q "running"; do
        sleep 5
    done
    
    # Wait for SSH to be available
    print_status "Waiting for SSH connectivity..."
    while ! ssh -i $SSH_KEY -o ConnectTimeout=5 -o StrictHostKeyChecking=no $SSH_USER@$node_ip "echo 'SSH ready'" &> /dev/null; do
        sleep 10
    done
    
    print_status "VM $node_name is running and SSH is available"
}

# Function to stop a worker node
stop_worker_node() {
    local node_name=$1
    local node_ip=$2
    
    print_status "Stopping worker node: $node_name ($node_ip)"
    
    # Drain the node first
    print_status "Draining node from Kubernetes cluster..."
    kubectl drain $node_name --ignore-daemonsets --delete-emptydir-data --force --timeout=300s || true
    
    # Delete the node from Kubernetes
    print_status "Removing node from Kubernetes cluster..."
    kubectl delete node $node_name || true
    
    # Stop the VM
    virsh shutdown $node_name
    
    # Wait for VM to be shut down
    print_status "Waiting for VM to shut down..."
    while virsh domstate $node_name | grep -q "running"; do
        sleep 5
    done
    
    print_status "VM $node_name has been stopped"
}

# Function to join a worker node to the cluster
join_worker_node() {
    local node_name=$1
    local node_ip=$2
    
    print_status "Joining worker node to cluster: $node_name ($node_ip)"
    
    # Get join command
    local join_command=$(get_join_command)
    
    if [ -z "$join_command" ]; then
        print_error "Failed to get join command from control plane"
        return 1
    fi
    
    # Execute join command on the worker node
    print_status "Executing join command on $node_name..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$node_ip "sudo $join_command"
    
    # Wait for node to be ready
    print_status "Waiting for node to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get node $node_name | grep -q "Ready"; then
            print_status "Node $node_name is ready!"
            return 0
        fi
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_error "Node $node_name failed to become ready within timeout"
    return 1
}

# Function to scale up (add worker nodes)
scale_up() {
    local count=$1
    
    print_header "Scaling up cluster by $count nodes"
    
    check_kubectl
    check_cluster
    
    local added_count=0
    
    for node_info in "${AUTOSCALING_NODES[@]}"; do
        if [ $added_count -ge $count ]; then
            break
        fi
        
        IFS=':' read -r node_name node_ip <<< "$node_info"
        
        # Check if node is already running
        if virsh domstate $node_name | grep -q "running"; then
            print_warning "Node $node_name is already running, skipping..."
            continue
        fi
        
        # Check if node is already in the cluster
        if kubectl get node $node_name &> /dev/null; then
            print_warning "Node $node_name is already in the cluster, skipping..."
            continue
        fi
        
        print_status "Adding node $node_name to the cluster..."
        
        if start_worker_node $node_name $node_ip && join_worker_node $node_name $node_ip; then
            print_status "Successfully added node $node_name to the cluster"
            added_count=$((added_count + 1))
        else
            print_error "Failed to add node $node_name to the cluster"
            stop_worker_node $node_name $node_ip
        fi
    done
    
    print_status "Scale up completed. Added $added_count nodes to the cluster."
}

# Function to scale down (remove worker nodes)
scale_down() {
    local count=$1
    
    print_header "Scaling down cluster by $count nodes"
    
    check_kubectl
    check_cluster
    
    # Get current worker nodes (excluding control plane nodes)
    local worker_nodes=($(kubectl get nodes --no-headers | grep -v "control-plane" | awk '{print $1}'))
    
    if [ ${#worker_nodes[@]} -le 3 ]; then
        print_warning "Cannot scale down below 3 worker nodes"
        return 1
    fi
    
    local removed_count=0
    
    # Start from the end of the worker nodes list (newest nodes first)
    for ((i=${#worker_nodes[@]}-1; i>=0 && removed_count<count; i--)); do
        local node_name=${worker_nodes[$i]}
        
        # Skip if it's one of the original 3 worker nodes
        if [[ "$node_name" =~ ^kworker[1-3]$ ]]; then
            continue
        fi
        
        # Find the IP for this node
        local node_ip=""
        for node_info in "${AUTOSCALING_NODES[@]}"; do
            IFS=':' read -r name ip <<< "$node_info"
            if [ "$name" = "$node_name" ]; then
                node_ip=$ip
                break
            fi
        done
        
        if [ -z "$node_ip" ]; then
            print_warning "Could not find IP for node $node_name, skipping..."
            continue
        fi
        
        print_status "Removing node $node_name from the cluster..."
        
        if stop_worker_node $node_name $node_ip; then
            print_status "Successfully removed node $node_name from the cluster"
            removed_count=$((removed_count + 1))
        else
            print_error "Failed to remove node $node_name from the cluster"
        fi
    done
    
    print_status "Scale down completed. Removed $removed_count nodes from the cluster."
}

# Function to show cluster status
show_status() {
    print_header "Cluster Status"
    
    check_kubectl
    check_cluster
    
    echo ""
    print_status "Kubernetes Nodes:"
    kubectl get nodes -o wide
    
    echo ""
    print_status "Autoscaling Nodes Status:"
    for node_info in "${AUTOSCALING_NODES[@]}"; do
        IFS=':' read -r node_name node_ip <<< "$node_info"
        local vm_state=$(virsh domstate $node_name 2>/dev/null || echo "not found")
        local k8s_status="not in cluster"
        
        if kubectl get node $node_name &> /dev/null; then
            k8s_status=$(kubectl get node $node_name --no-headers | awk '{print $2}')
        fi
        
        echo "  $node_name: VM=$vm_state, K8s=$k8s_status"
    done
    
    echo ""
    print_status "Cluster Autoscaler Status:"
    kubectl get pods -n cluster-autoscaler 2>/dev/null || echo "  Cluster autoscaler not installed"
    
    echo ""
    print_status "HPA Status:"
    kubectl get hpa -A 2>/dev/null || echo "  No HPA found"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  scale-up [COUNT]     Scale up the cluster by adding worker nodes"
    echo "  scale-down [COUNT]   Scale down the cluster by removing worker nodes"
    echo "  status              Show cluster and autoscaling status"
    echo "  start-node [NAME]   Start a specific worker node"
    echo "  stop-node [NAME]    Stop a specific worker node"
    echo "  join-node [NAME]    Join a specific worker node to the cluster"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 scale-up 2       Add 2 worker nodes to the cluster"
    echo "  $0 scale-down 1     Remove 1 worker node from the cluster"
    echo "  $0 status           Show current cluster status"
    echo "  $0 start-node kworker4"
}

# Main script logic
case "${1:-help}" in
    "scale-up")
        count=${2:-1}
        scale_up $count
        ;;
    "scale-down")
        count=${2:-1}
        scale_down $count
        ;;
    "status")
        show_status
        ;;
    "start-node")
        node_name=${2:-}
        if [ -z "$node_name" ]; then
            print_error "Node name is required"
            exit 1
        fi
        
        # Find the node info
        for node_info in "${AUTOSCALING_NODES[@]}"; do
            IFS=':' read -r name ip <<< "$node_info"
            if [ "$name" = "$node_name" ]; then
                start_worker_node $name $ip
                exit 0
            fi
        done
        print_error "Node $node_name not found in autoscaling configuration"
        exit 1
        ;;
    "stop-node")
        node_name=${2:-}
        if [ -z "$node_name" ]; then
            print_error "Node name is required"
            exit 1
        fi
        
        # Find the node info
        for node_info in "${AUTOSCALING_NODES[@]}"; do
            IFS=':' read -r name ip <<< "$node_info"
            if [ "$name" = "$node_name" ]; then
                stop_worker_node $name $ip
                exit 0
            fi
        done
        print_error "Node $node_name not found in autoscaling configuration"
        exit 1
        ;;
    "join-node")
        node_name=${2:-}
        if [ -z "$node_name" ]; then
            print_error "Node name is required"
            exit 1
        fi
        
        # Find the node info
        for node_info in "${AUTOSCALING_NODES[@]}"; do
            IFS=':' read -r name ip <<< "$node_info"
            if [ "$name" = "$node_name" ]; then
                join_worker_node $name $ip
                exit 0
            fi
        done
        print_error "Node $node_name not found in autoscaling configuration"
        exit 1
        ;;
    "help"|*)
        show_usage
        ;;
esac
