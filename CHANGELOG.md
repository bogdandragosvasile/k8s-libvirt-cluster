# Changelog

All notable changes to the k8s-libvirt-cluster project will be documented in this file.

## [1.1.0] - 2025-08-16

### 🚀 Added
- **MetalLB Load Balancer**: Integrated MetalLB v0.15.2 for L2 load balancing with dedicated IP pool (192.168.122.240-250)
- **Nginx Ingress Controller**: Deployed Nginx Ingress Controller with LoadBalancer service type and dedicated IP (192.168.122.230)
- **SSL Termination**: Configured local Nginx proxy for SSL termination and secure access to Kubernetes services
- **Ingress Resources**: Created sample ingress configuration for testing end-to-end connectivity
- **IP Pool Management**: Implemented separate MetalLB IP pools for different service types
- **Pipeline Integration**: Added automated installation stages for MetalLB and Ingress Controller in Jenkins pipeline

### 🔧 Enhanced
- **Jenkins Pipeline**: Extended pipeline with conditional stages for MetalLB and Ingress Controller installation
- **Script-Based Deployment**: Moved complex installation logic to dedicated bash scripts for better maintainability
- **Error Handling**: Improved error handling and logging in installation scripts
- **Verification Steps**: Added comprehensive verification and testing steps for new components

### 🛠️ Technical Improvements
- **Load Balancer Integration**: Services can now receive external IP addresses automatically
- **Ingress Routing**: HTTP/HTTPS traffic routing based on hostnames and paths
- **Port Conflicts Resolution**: Resolved MetalLB IP pool overlapping issues
- **SSL Proxy Configuration**: Configured secure access via port 8443 with proper SSL certificates

### 🌐 Infrastructure
- **External Access**: Enabled external access to Kubernetes services via ingress controller
- **Service Discovery**: Improved service discovery and routing capabilities
- **High Availability**: Enhanced cluster availability with proper load balancing

### 📊 Cluster Specifications
- **Control Planes**: 3 nodes (kcontrolplane1-3) - Ready
- **Worker Nodes**: 3 nodes (kworker1-3) - Ready  
- **Load Balancer VMs**: 2 nodes (loadbalancer1-2) - Active
- **Kubernetes Version**: v1.30.1
- **Container Runtime**: containerd 1.7.27
- **CNI**: Calico
- **OS**: Ubuntu 24.04.3 LTS

### 🔐 Security
- **SSL/TLS**: End-to-end encryption for all web traffic
- **Certificate Management**: Let's Encrypt SSL certificates integration
- **Network Policies**: Enhanced network security with Calico CNI

### 🧪 Testing
- **End-to-End Tests**: Verified complete request flow from external client to pod
- **Load Balancer Tests**: Confirmed external IP assignment and traffic routing
- **Ingress Tests**: Validated hostname-based routing and SSL termination
- **Service Discovery**: Tested internal and external service resolution

### 🚀 Deployment
- **Zero Downtime**: New components deployed without disrupting existing services  
- **Backward Compatibility**: Existing services continue to function normally
- **Pipeline Automation**: Fully automated deployment via Jenkins CI/CD

### 📈 Performance
- **Hardware Utilization**: Optimized for AMD Ryzen 9 7945HX (32 cores) with 64GB DDR5
- **Storage**: Efficient utilization of 1TB NVMe SSD for VM images and container storage
- **Network**: Enhanced network performance with MetalLB L2 mode

## [1.0.0] - 2025-08-14

### 🚀 Initial Release
- **Kubernetes Cluster**: High-availability cluster with 3 control planes and 3 workers
- **Infrastructure as Code**: Terraform-based VM provisioning on libvirt/KVM
- **Configuration Management**: Ansible-based cluster configuration and deployment
- **CI/CD Pipeline**: Jenkins automation for complete cluster lifecycle management
- **Container Networking**: Calico CNI for pod-to-pod communication
- **Service Discovery**: CoreDNS for internal cluster DNS resolution
- **Load Balancer Infrastructure**: HAProxy-based load balancer VMs for API server HA
