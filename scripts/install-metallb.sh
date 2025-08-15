#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}[Installing and configuring MetalLB]${NC}"

# Enable strict ARP mode for IPVS
echo -e "${YELLOW}Enabling strict ARP mode...${NC}"
kubectl get configmap kube-proxy -n kube-system -o yaml | \
  sed -e 's/strictARP: false/strictARP: true/' | \
  kubectl apply -f - -n kube-system

# Install MetalLB
echo -e "${YELLOW}Installing MetalLB v0.15.2...${NC}"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

# Wait for MetalLB components to be ready
echo -e "${YELLOW}Waiting for MetalLB components to be ready...${NC}"
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=300s

# Create IP Address Pool
echo -e "${YELLOW}Creating MetalLB IP Address Pool...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.122.240-192.168.122.250
EOF

# Create L2 Advertisement
echo -e "${YELLOW}Creating MetalLB L2 Advertisement...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2advertisement
  namespace: metallb-system
EOF

# Verify installation
echo -e "${YELLOW}Verifying MetalLB installation...${NC}"
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# Create test service
echo -e "${YELLOW}Creating test LoadBalancer service...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: nginx-test
  ports:
  - port: 80
    targetPort: 80
EOF

# Wait for external IP assignment with proper bash loop
echo -e "${YELLOW}Waiting for external IP assignment...${NC}"
for i in {1..10}; do
    EXTERNAL_IP=$(kubectl get svc nginx-test-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '')
    if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]]; then
        echo -e "${GREEN}✅ External IP assigned: $EXTERNAL_IP${NC}"
        if curl -f http://$EXTERNAL_IP --max-time 10 >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Service is accessible!${NC}"
        else
            echo -e "${YELLOW}⚠️ Service not yet accessible${NC}"
        fi
        break
    fi
    echo "Waiting for external IP... (attempt $i/10)"
    sleep 30
done

# Final status
echo -e "${YELLOW}Final service status:${NC}"
kubectl get svc nginx-test-loadbalancer

echo -e "${GREEN}🎉 MetalLB installation and configuration complete!${NC}"
