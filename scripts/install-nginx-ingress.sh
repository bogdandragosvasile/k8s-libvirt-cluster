#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}[Installing Nginx Ingress Controller with MetalLB]${NC}"

# Configuration - Use IP outside existing range
INGRESS_IP="192.168.122.230"  # Changed from .241 to .230
METALLB_NAMESPACE="metallb-system"

echo -e "${YELLOW}Installing Nginx Ingress Controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

echo -e "${YELLOW}Waiting for ingress controller deployment...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo -e "${YELLOW}Patching ingress controller to use LoadBalancer...${NC}"
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"LoadBalancer"}}'

echo -e "${YELLOW}Creating dedicated MetalLB IP pool for ingress...${NC}"
# Create dedicated IP pool for ingress controller
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ingress-pool
  namespace: ${METALLB_NAMESPACE}
spec:
  addresses:
  - ${INGRESS_IP}/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: ingress-l2advertisement
  namespace: ${METALLB_NAMESPACE}
spec:
  ipAddressPools:
  - ingress-pool
EOF

# Force assignment of specific IP to ingress controller
echo -e "${YELLOW}Assigning specific IP to ingress controller...${NC}"
kubectl annotate svc ingress-nginx-controller -n ingress-nginx metallb.universe.tf/address-pool=ingress-pool --overwrite

echo -e "${YELLOW}Waiting for external IP assignment...${NC}"
for i in {1..20}; do
    EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '')
    if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]]; then
        echo -e "${GREEN}✅ Ingress controller external IP assigned: $EXTERNAL_IP${NC}"
        break
    fi
    echo "Waiting for external IP assignment... (attempt $i/20)"
    sleep 15
done

echo -e "${YELLOW}Verifying ingress installation...${NC}"
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

echo -e "${YELLOW}Creating test ingress resource...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: test.k8s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-test-loadbalancer
            port:
              number: 80
EOF

echo -e "${GREEN}🎉 Nginx Ingress Controller installation and configuration complete!${NC}"
echo -e "${BLUE}Ingress Controller IP: ${EXTERNAL_IP}${NC}"
echo -e "${BLUE}You can test with: curl -H \"Host: test.k8s.local\" http://${EXTERNAL_IP}${NC}"
