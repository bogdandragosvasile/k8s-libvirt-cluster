#!/bin/bash

# Cluster Autoscaler Installation Script
# This script installs and configures the Cluster Autoscaler for the Kubernetes cluster

set -e

echo "🚀 Installing Cluster Autoscaler..."

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

# Get cluster information
CLUSTER_NAME=$(kubectl config current-context)
print_status "Installing Cluster Autoscaler for cluster: $CLUSTER_NAME"

# Create namespace for cluster autoscaler
print_status "Creating cluster-autoscaler namespace..."
kubectl create namespace cluster-autoscaler --dry-run=client -o yaml | kubectl apply -f -

# Create service account and RBAC
print_status "Creating RBAC resources..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-autoscaler
  namespace: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
rules:
  - apiGroups: [""]
    resources: ["events", "endpoints"]
    verbs: ["create", "patch"]
  - apiGroups: [""]
    resources: ["pods/eviction"]
    verbs: ["create"]
  - apiGroups: [""]
    resources: ["pods/status"]
    verbs: ["update"]
  - apiGroups: [""]
    resources: ["endpoints"]
    resourceNames: ["cluster-autoscaler"]
    verbs: ["get", "update"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["watch", "list", "get", "update"]
  - apiGroups: [""]
    resources: ["namespaces", "pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
    verbs: ["watch", "list", "get"]
  - apiGroups: ["extensions"]
    resources: ["replicasets", "daemonsets"]
    verbs: ["watch", "list", "get"]
  - apiGroups: ["policy"]
    resources: ["poddisruptionbudgets"]
    verbs: ["watch", "list"]
  - apiGroups: ["apps"]
    resources: ["statefulsets", "replicasets", "daemonsets"]
    verbs: ["watch", "list", "get"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses", "csinodes", "csidrivers", "csistoragecapacities"]
    verbs: ["watch", "list", "get"]
  - apiGroups: ["batch", "extensions"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch", "patch"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["create"]
  - apiGroups: ["coordination.k8s.io"]
    resourceNames: ["cluster-autoscaler"]
    resources: ["leases"]
    verbs: ["get", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cluster-autoscaler
  namespace: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["create","list","watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["cluster-autoscaler-status", "cluster-autoscaler-priority-expander"]
    verbs: ["delete", "get", "update", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-autoscaler
subjects:
  - kind: ServiceAccount
    name: cluster-autoscaler
    namespace: cluster-autoscaler
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cluster-autoscaler
  namespace: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cluster-autoscaler
subjects:
  - kind: ServiceAccount
    name: cluster-autoscaler
    namespace: cluster-autoscaler
EOF

# Create deployment for cluster autoscaler
print_status "Creating Cluster Autoscaler deployment..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: cluster-autoscaler
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
        - image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.30.1
          name: cluster-autoscaler
          resources:
            limits:
              cpu: 100m
              memory: 300Mi
            requests:
              cpu: 100m
              memory: 300Mi
          command:
            - ./cluster-autoscaler
            - --v=4
            - --stderrthreshold=info
            - --cloud-provider=libvirt
            - --nodes=1:10:kworker
            - --scale-down-delay-after-add=10m
            - --scale-down-delay-after-delete=10s
            - --scale-down-delay-after-failure=3m
            - --scale-down-unneeded-time=10m
            - --max-node-provision-time=15m
            - --ok-total-unready-count=3
            - --max-total-unready-percentage=45
            - --scale-down-enabled=true
            - --scale-down-utilization-threshold=0.5
            - --skip-nodes-with-local-storage=false
            - --skip-nodes-with-system-pods=false
            - --balance-similar-node-groups=true
            - --expander=least-waste
            - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/instance-type
          volumeMounts:
            - name: ssl-certs
              mountPath: /etc/ssl/certs/ca-bundle.crt
              readOnly: true
          imagePullPolicy: "Always"
      volumes:
        - name: ssl-certs
          hostPath:
            path: "/etc/ssl/certs/ca-bundle.crt"
EOF

# Create ConfigMap for autoscaler configuration
print_status "Creating Cluster Autoscaler ConfigMap..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-status
  namespace: cluster-autoscaler
data:
  status: "true"
EOF

# Wait for deployment to be ready
print_status "Waiting for Cluster Autoscaler deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cluster-autoscaler -n cluster-autoscaler

# Check deployment status
print_status "Checking Cluster Autoscaler status..."
kubectl get pods -n cluster-autoscaler

# Create a test deployment to verify autoscaling
print_status "Creating test deployment for autoscaling verification..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: autoscaling-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: autoscaling-test
  template:
    metadata:
      labels:
        app: autoscaling-test
    spec:
      containers:
      - name: stress-test
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Running stress test'; sleep 30; done"]
        resources:
          requests:
            memory: "100Mi"
            cpu: "100m"
          limits:
            memory: "200Mi"
            cpu: "200m"
EOF

# Create HPA for the test deployment
print_status "Creating Horizontal Pod Autoscaler for test deployment..."
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: autoscaling-test-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: autoscaling-test
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 50
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

print_status "✅ Cluster Autoscaler installation completed successfully!"
print_status "📊 You can monitor the autoscaler with:"
echo "   kubectl logs -f deployment/cluster-autoscaler -n cluster-autoscaler"
echo "   kubectl get hpa -A"
echo "   kubectl get nodes"
print_status "🧪 Test autoscaling by scaling the test deployment:"
echo "   kubectl scale deployment autoscaling-test --replicas=5"
