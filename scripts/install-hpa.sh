#!/bin/bash

# Horizontal Pod Autoscaler (HPA) Installation Script
# This script installs the metrics server and configures HPA for the Kubernetes cluster

set -e

echo "🚀 Installing Horizontal Pod Autoscaler (HPA)..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Installing Metrics Server..."

# Install metrics server
print_status "Downloading and applying metrics server manifests..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for metrics server to be ready
print_status "Waiting for metrics server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

# Patch metrics server to work with self-signed certificates
print_status "Patching metrics server for self-signed certificates..."
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait for the patch to take effect
print_status "Waiting for metrics server to restart..."
kubectl rollout restart deployment/metrics-server -n kube-system
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

# Test metrics server
print_status "Testing metrics server..."
sleep 30
if kubectl top nodes &> /dev/null; then
    print_status "✅ Metrics server is working correctly!"
else
    print_warning "⚠️  Metrics server might need more time to start. You can check with: kubectl top nodes"
fi

# Create sample applications for HPA testing
print_status "Creating sample applications for HPA testing..."

# Create namespace for sample apps
kubectl create namespace hpa-demo --dry-run=client -o yaml | kubectl apply -f -

# Create a CPU-intensive application
print_status "Creating CPU-intensive test application..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-intensive-app
  namespace: hpa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-intensive-app
  template:
    metadata:
      labels:
        app: cpu-intensive-app
    spec:
      containers:
      - name: cpu-intensive
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'CPU intensive task'; dd if=/dev/zero of=/dev/null bs=1M count=1000; done"]
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: cpu-intensive-app-service
  namespace: hpa-demo
spec:
  selector:
    app: cpu-intensive-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF

# Create HPA for CPU-intensive app
print_status "Creating HPA for CPU-intensive application..."
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cpu-intensive-app-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cpu-intensive-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
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

# Create a memory-intensive application
print_status "Creating memory-intensive test application..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memory-intensive-app
  namespace: hpa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: memory-intensive-app
  template:
    metadata:
      labels:
        app: memory-intensive-app
    spec:
      containers:
      - name: memory-intensive
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Memory intensive task'; tail -c 50M /dev/zero > /tmp/memory_test; sleep 10; done"]
        resources:
          requests:
            memory: "100Mi"
            cpu: "50m"
          limits:
            memory: "200Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: memory-intensive-app-service
  namespace: hpa-demo
spec:
  selector:
    app: memory-intensive-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF

# Create HPA for memory-intensive app
print_status "Creating HPA for memory-intensive application..."
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: memory-intensive-app-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: memory-intensive-app
  minReplicas: 1
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
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

# Create a web application with custom metrics (simulated)
print_status "Creating web application with custom metrics..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: hpa-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-server
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
  namespace: hpa-demo
spec:
  selector:
    app: web-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF

# Create HPA for web app with multiple metrics
print_status "Creating HPA for web application..."
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
  namespace: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
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

# Create a load generator for testing
print_status "Creating load generator for testing..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-generator
  namespace: hpa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: load-generator
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      containers:
      - name: load-gen
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do wget -q -O- http://web-app-service.hpa-demo.svc.cluster.local/; sleep 1; done"]
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF

print_status "✅ HPA installation completed successfully!"
print_status "📊 You can monitor HPA with:"
echo "   kubectl get hpa -n hpa-demo"
echo "   kubectl top pods -n hpa-demo"
echo "   kubectl top nodes"
print_status "🧪 Test HPA by generating load:"
echo "   kubectl scale deployment load-generator --replicas=3 -n hpa-demo"
echo "   kubectl scale deployment cpu-intensive-app --replicas=5 -n hpa-demo"
print_status "📈 Monitor scaling events:"
echo "   kubectl describe hpa -n hpa-demo"
echo "   kubectl get events -n hpa-demo --sort-by='.lastTimestamp'"
