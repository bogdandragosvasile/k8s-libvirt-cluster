# 🚀 Enhanced Multi-Distribution Kubernetes Cluster with Network Flexibility

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Kubernetes](https://img.shields.io/badge/kubernetes-v1.30.1-blue.svg)
![Terraform](https://img.shields.io/badge/terraform-1.6+-orange.svg)
![Ansible](https://img.shields.io/badge/ansible-2.14+-red.svg)

## 🌟 **Major Enhancements (v2.0.0)**

This enhanced version provides **revolutionary flexibility** for Kubernetes cluster deployment across multiple Linux distributions and network configurations, with automated prerequisites installation and comprehensive validation.

### 🎯 **Key New Features**

✅ **Multi-Distribution Support**: Ubuntu, CentOS, Rocky Linux, Debian, openSUSE  
✅ **Network Flexibility**: NAT (isolated) and Bridge (host network) modes  
✅ **Automated Prerequisites**: One-command installation on clean systems  
✅ **Dynamic Configuration**: Runtime distribution and network selection  
✅ **Enhanced Services**: MetalLB, Nginx Ingress, cert-manager with Let's Encrypt  
✅ **Comprehensive Validation**: End-to-end deployment testing  
✅ **Smart Image Management**: Automatic distribution image downloads  

---

## 📋 **Table of Contents**

- [Enhanced Features](#-enhanced-features)
- [Supported Distributions](#-supported-distributions)
- [Network Modes](#-network-modes)
- [Quick Start](#-quick-start)
- [Detailed Setup](#-detailed-setup)
- [Usage Examples](#-usage-examples)
- [Configuration Reference](#-configuration-reference)
- [Troubleshooting](#-troubleshooting)
- [Validation & Testing](#-validation--testing)

---

## 🚀 **Enhanced Features**

### **Multi-Distribution Support**
| Distribution | Package Manager | Status | Notes |
|-------------|----------------|---------|-------|
| Ubuntu 24.04/22.04/20.04 | apt | ✅ Full | Primary development target |
| CentOS 9/8 Stream | dnf | ✅ Full | Enterprise-ready |
| Rocky Linux 9/8 | dnf | ✅ Full | RHEL alternative |
| Debian 12/11 | apt | ✅ Full | Stable deployment |
| openSUSE Leap 15.5/15.4 | zypper | ✅ Full | Enterprise Linux |

### **Network Flexibility**
| Mode | Description | Use Case | IP Range |
|------|-------------|----------|----------|
| **NAT** | Isolated VM network | Development, Testing | 192.168.122.x |
| **Bridge** | VMs on host network | Production, Integration | Host network range |

### **Automated Services**
- **MetalLB v0.15.2**: L2 load balancing with auto-configured IP pools
- **Nginx Ingress Controller**: HTTP/HTTPS routing with SSL termination
- **cert-manager v1.15.3**: Automated SSL certificates with Let's Encrypt
- **Calico CNI**: Advanced networking and security policies

---

## 🖥️ **Supported Distributions**

### **Ubuntu Family**
```bash
# Ubuntu 24.04 LTS (Noble Numbat) - Recommended
LINUX_DISTRO=ubuntu-24.04

# Ubuntu 22.04 LTS (Jammy Jellyfish) - Stable
LINUX_DISTRO=ubuntu-22.04

# Ubuntu 20.04 LTS (Focal Fossa) - Legacy
LINUX_DISTRO=ubuntu-20.04
```

### **Red Hat Family**
```bash
# CentOS 9 Stream - Latest
LINUX_DISTRO=centos-9

# Rocky Linux 9 - RHEL Alternative
LINUX_DISTRO=rocky-9

# CentOS 8 Stream - Stable
LINUX_DISTRO=centos-8
```

### **Debian Family**
```bash
# Debian 12 (Bookworm) - Latest
LINUX_DISTRO=debian-12

# Debian 11 (Bullseye) - Stable
LINUX_DISTRO=debian-11
```

### **SUSE Family**
```bash
# openSUSE Leap 15.5 - Latest
LINUX_DISTRO=opensuse-15.5

# openSUSE Leap 15.4 - Stable
LINUX_DISTRO=opensuse-15.4
```

---

## 🌐 **Network Modes**

### **NAT Mode (Default)**
- **Isolated Network**: VMs use NAT for internet access
- **IP Range**: 192.168.122.0/24
- **MetalLB Range**: 192.168.122.240-250
- **Use Case**: Development, testing, isolated environments

```bash
NETWORK_MODE=nat
```

### **Bridge Mode**
- **Host Network**: VMs directly on host network
- **IP Range**: Host network (e.g., 192.168.1.0/24)
- **MetalLB Range**: Auto-calculated from host network
- **Use Case**: Production, integration with existing infrastructure

```bash
NETWORK_MODE=bridge
BRIDGE_INTERFACE=br0
NETWORK_CIDR=192.168.1.0/24
```

---

## ⚡ **Quick Start**

### **Option 1: Automated Clean System Setup**

For a **completely clean Linux system**, use our automated installer:

```bash
# Download and run the prerequisites installer
curl -fsSL https://raw.githubusercontent.com/yourusername/k8s-libvirt-cluster/feature/multi-distro-network-flexibility/scripts/install-prerequisites.sh | sudo bash

# Clone the enhanced repository
git clone https://github.com/yourusername/k8s-libvirt-cluster.git
cd k8s-libvirt-cluster
git checkout feature/multi-distro-network-flexibility

# Generate SSH keys
ssh-keygen -t ed25519 -f ~/.ssh/k8s-cluster -N ""

# Configure Jenkins (see Detailed Setup for credentials)
```

### **Option 2: Existing System with Prerequisites**

If you already have the prerequisites installed:

```bash
# Clone and switch to enhanced branch
git clone https://github.com/yourusername/k8s-libvirt-cluster.git
cd k8s-libvirt-cluster
git checkout feature/multi-distro-network-flexibility

# Download base images for your chosen distribution
sudo ./scripts/download-base-images.sh ubuntu-24.04

# Configure Jenkins pipeline (see Jenkins Setup)
```

---

## 🔧 **Detailed Setup**

### **1. Prerequisites Installation**

The automated installer handles everything:

```bash
# Run as root or with sudo
curl -fsSL https://raw.githubusercontent.com/yourusername/k8s-libvirt-cluster/feature/multi-distro-network-flexibility/scripts/install-prerequisites.sh | sudo bash
```

**What it installs:**
- KVM/libvirt virtualization
- Docker with user permissions
- Terraform latest version
- Ansible latest version
- Jenkins with required plugins
- kubectl and basic tools

### **2. Jenkins Configuration**

#### **Initial Setup**
```bash
# Get Jenkins initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Access Jenkins
http://localhost:8080
```

#### **Required Plugins**
Install these plugins via Jenkins UI:
- Docker Pipeline
- SSH Agent  
- Credentials Binding
- Git
- AnsiColor
- Timestamper

#### **Credentials Setup**
Create these credentials in Jenkins:

| Credential ID | Type | Description |
|---------------|------|-------------|
| `kube-ssh-public-key` | Secret text | SSH public key content |
| `github-ssh-key` | SSH Username with private key | GitHub access |

```bash
# Generate SSH keys
ssh-keygen -t ed25519 -f ~/.ssh/k8s-cluster -N ""

# Display public key (for Jenkins credential)
cat ~/.ssh/k8s-cluster.pub

# Display private key (for GitHub credential) 
cat ~/.ssh/k8s-cluster
```

### **3. Pipeline Setup**

1. **Create New Pipeline**
   - Jenkins → New Item → Pipeline
   - Name: `enhanced-k8s-cluster`

2. **Configure Source**
   - Pipeline script from SCM
   - Git URL: `https://github.com/yourusername/k8s-libvirt-cluster.git`
   - Branch: `feature/multi-distro-network-flexibility`
   - Script Path: `jenkins/Jenkinsfile`

3. **First Run**
   - Build with Parameters
   - Select your preferred configuration
   - Monitor deployment progress

---

## 🎮 **Usage Examples**

### **Example 1: Development Setup (Ubuntu + NAT)**
```bash
# Jenkins Pipeline Parameters:
LINUX_DISTRO: ubuntu-24.04
NETWORK_MODE: nat
CP_MEMORY: 4096
WORKER_MEMORY: 8192
INSTALL_METALLB: true
INSTALL_INGRESS: true
INSTALL_CERTMANAGER: false
```

### **Example 2: Production Setup (Rocky Linux + Bridge)**
```bash
# Jenkins Pipeline Parameters:
LINUX_DISTRO: rocky-9
NETWORK_MODE: bridge
BRIDGE_INTERFACE: br0
NETWORK_CIDR: 10.0.1.0/24
METALLB_IP_RANGE: 10.0.1.240-10.0.1.250
CP_MEMORY: 8192
WORKER_MEMORY: 16384
LETSENCRYPT_EMAIL: admin@company.com
LETSENCRYPT_STAGING: false
```

### **Example 3: Testing Multiple Distributions**
```bash
# Script to test all distributions
for distro in ubuntu-24.04 centos-9 rocky-9 debian-12 opensuse-15.5; do
  echo "Testing $distro..."
  # Trigger Jenkins build with $distro
  # Run validation
  ./scripts/validate-deployment.sh --quick
done
```

---

## ⚙️ **Configuration Reference**

### **Jenkins Pipeline Parameters**

#### **Core Configuration**
```yaml
LINUX_DISTRO: "ubuntu-24.04"           # Distribution selection
NETWORK_MODE: "nat"                    # nat or bridge
SKIP_TERRAFORM: false                  # Skip infrastructure
SKIP_ANSIBLE: false                    # Skip configuration
```

#### **Network Configuration**
```yaml
BRIDGE_INTERFACE: "br0"                # Bridge interface name
NETWORK_CIDR: "192.168.1.0/24"        # Network CIDR
METALLB_IP_RANGE: "192.168.1.240-250" # MetalLB IP range
```

#### **Resource Allocation**
```yaml
CP_MEMORY: "4096"                      # Control plane RAM (MB)
CP_CPU: "2"                           # Control plane vCPUs
WORKER_MEMORY: "8192"                 # Worker RAM (MB)
WORKER_CPU: "4"                       # Worker vCPUs
```

#### **Services Configuration**
```yaml
INSTALL_METALLB: true                  # Install MetalLB
INSTALL_INGRESS: true                  # Install Nginx Ingress
INSTALL_CERTMANAGER: true              # Install cert-manager
```

#### **SSL/TLS Configuration**
```yaml
LETSENCRYPT_EMAIL: "admin@example.com" # Let's Encrypt email
LETSENCRYPT_STAGING: true              # Use staging environment
```

### **Terraform Variables**

All Jenkins parameters are automatically converted to Terraform variables. You can also set them manually:

```hcl
# terraform/terraform.tfvars
linux_distro = "ubuntu-24.04"
network_mode = "bridge"
bridge_interface = "br0"
cp_memory_mb = 4096
worker_memory_mb = 8192
metallb_ip_range = "192.168.1.240-192.168.1.250"
```

---

## 🔍 **Validation & Testing**

### **Comprehensive Validation**
```bash
# Run full validation suite
./scripts/validate-deployment.sh

# Quick validation
./scripts/validate-deployment.sh --quick

# Infrastructure only
./scripts/validate-deployment.sh --infrastructure

# Services only  
./scripts/validate-deployment.sh --services
```

### **Validation Categories**

1. **Infrastructure Tests**
   - Terraform state validation
   - VM status and resources
   - Network connectivity

2. **Kubernetes Tests**
   - Cluster connectivity
   - Node status and readiness
   - System pods health

3. **Service Tests**
   - MetalLB functionality
   - Nginx Ingress Controller
   - cert-manager and SSL

4. **Distribution Tests**
   - Package manager compatibility
   - Service configuration
   - User and permissions

5. **Integration Tests**
   - End-to-end application deployment
   - Service discovery
   - Load balancing

### **Manual Testing**

```bash
# Access cluster
ssh -i ~/.ssh/k8s-cluster ubuntu@192.168.122.101

# Check cluster status
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Test MetalLB
kubectl get svc --all-namespaces | grep LoadBalancer

# Test Ingress
kubectl get ingress --all-namespaces

# Test cert-manager
kubectl get certificates --all-namespaces
kubectl get clusterissuers
```

---

## 🚨 **Troubleshooting**

### **Common Issues and Solutions**

#### **1. VM Creation Failures**
```bash
# Check libvirt status
sudo systemctl status libvirtd

# Check available storage
df -h /var/lib/libvirt/images

# Check network conflicts
virsh net-list --all
```

#### **2. Base Image Download Issues**
```bash
# Manual image download
sudo ./scripts/download-base-images.sh --all

# Check image status
sudo ./scripts/download-base-images.sh --info

# Clean old images
sudo ./scripts/download-base-images.sh --cleanup
```

#### **3. SSH Connectivity Problems**
```bash
# Check SSH key permissions
ls -la ~/.ssh/k8s-cluster*
chmod 600 ~/.ssh/k8s-cluster

# Test manual SSH
ssh -i ~/.ssh/k8s-cluster -o StrictHostKeyChecking=no ubuntu@192.168.122.101

# Check VM console
virsh console kcontrolplane1
```

#### **4. Network Configuration Issues**

**NAT Mode:**
```bash
# Check default network
virsh net-list --all
virsh net-info default

# Restart network
virsh net-destroy default
virsh net-start default
```

**Bridge Mode:**
```bash
# Check bridge interface
ip link show br0
brctl show br0

# Create bridge if missing
sudo ip link add name br0 type bridge
sudo ip link set dev br0 up
```

#### **5. Distribution-Specific Issues**

**CentOS/Rocky Linux:**
```bash
# Enable EPEL repository
sudo dnf install epel-release

# Check SELinux status
sestatus
sudo setenforce 0  # If needed temporarily
```

**openSUSE:**
```bash
# Update repositories
sudo zypper refresh

# Check firewall
sudo firewall-cmd --state
sudo firewall-cmd --list-all
```

#### **6. Service Installation Failures**

**MetalLB:**
```bash
# Check cluster connectivity
kubectl cluster-info

# Manual MetalLB installation
./scripts/install-metallb.sh --help
./scripts/install-metallb.sh --ip-range 192.168.1.240-192.168.1.250
```

**cert-manager:**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Verify webhook
kubectl get validatingwebhookconfiguration
```

### **Debug Mode**

Enable verbose logging:

```bash
# Terraform debug
export TF_LOG=DEBUG

# Ansible debug
export ANSIBLE_DEBUG=1

# Validation debug
./scripts/validate-deployment.sh --help
```

---

## 📊 **Performance Tuning**

### **Resource Recommendations**

#### **Development Environment**
- **Control Plane**: 2 vCPU, 4GB RAM
- **Workers**: 2 vCPU, 4GB RAM
- **Total**: 12 vCPU, 24GB RAM

#### **Production Environment**  
- **Control Plane**: 4 vCPU, 8GB RAM
- **Workers**: 8 vCPU, 16GB RAM
- **Total**: 36 vCPU, 72GB RAM

#### **Hardware Requirements**
- **Minimum**: 8 cores, 16GB RAM, 100GB SSD
- **Recommended**: 16+ cores, 32GB+ RAM, 500GB+ NVMe SSD
- **Optimal**: 32+ cores, 64GB+ RAM, 1TB+ NVMe SSD

### **Optimization Tips**

```bash
# Adjust VM resources in pipeline parameters
CP_MEMORY=8192    # Increase for production
WORKER_MEMORY=16384
WORKER_CPU=8

# Use faster storage
# Move /var/lib/libvirt/images to NVMe SSD
sudo systemctl stop libvirtd
sudo mv /var/lib/libvirt/images /mnt/nvme/libvirt-images
sudo ln -s /mnt/nvme/libvirt-images /var/lib/libvirt/images
sudo systemctl start libvirtd
```

---

## 🤝 **Contributing**

### **Development Workflow**

1. **Fork the repository**
2. **Create feature branch**
   ```bash
   git checkout -b feature/amazing-enhancement
   ```
3. **Make changes and test**
   ```bash
   # Test with multiple distributions
   ./scripts/validate-deployment.sh --quick
   ```
4. **Submit pull request**

### **Testing New Distributions**

1. **Add distribution to `terraform/distro_images.tf`**
2. **Update Ansible playbooks if needed**
3. **Add to Jenkins pipeline choices**
4. **Test deployment and validation**
5. **Update documentation**

---

## 📜 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 **Acknowledgments**

- **Original Project**: [gmhafiz/k8s-ha](https://github.com/gmhafiz/k8s-ha)
- **Kubernetes Community**: Excellent documentation and tools
- **HashiCorp**: Terraform infrastructure automation
- **Red Hat**: Ansible configuration management
- **MetalLB Project**: Load balancing for bare metal
- **cert-manager**: Automated certificate management
- **All Contributors**: Community feedback and improvements

---

## 📞 **Support**

- 🐛 **Issues**: [GitHub Issues](https://github.com/yourusername/k8s-libvirt-cluster/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/yourusername/k8s-libvirt-cluster/discussions)
- 📖 **Documentation**: [Project Wiki](https://github.com/yourusername/k8s-libvirt-cluster/wiki)

---

**🎉 Happy Multi-Distribution Kubernetes Clustering!**

*Deploy anywhere, on any distribution, with any network configuration!*
