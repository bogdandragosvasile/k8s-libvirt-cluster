<img src="https://upload.wikimedia.org/wikipedia/commons/d/da/Libvirt_logo.svg" style="height:64px;margin-right:32px"/><img src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/Kubernetes_logo_without_workmark.svg/500px-Kubernetes_logo_without_workmark.svg.png" style="height:64px;margin-right:32px"/><img src="https://www.aviator.co/blog/wp-content/uploads/2023/01/terraform.png" style="height:64px;margin-right:32px"/><img src="https://icon2.cleanpng.com/20180917/gvp/kisspng-starmetro-logo-product-content-computer-icons-5ba0580ea74853.5621064615372349586852.jpg" style="height:64px;margin-right:32px"/><img src="https://upload.wikimedia.org/wikipedia/commons/a/ab/Haproxy-logo.png" style="height:64px;margin-right:32px"/><img src="https://docs.convisoappsec.com/assets/images/jenkins-84750961bdf8ae419d123600b64026da.png" style="height:64px;margin-right:32px"/>


# Kubernetes HA Cluster with Jenkins CI/CD

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Kubernetes](https://img.shields.io/badge/kubernetes-v1.30.1-blue.svg)
![Autoscaling](https://img.shields.io/badge/autoscaling-enabled-green.svg)

🚀 **Automated deployment of a production-ready, highly available Kubernetes cluster with autoscaling using Terraform, Ansible, and Jenkins**

This is based on the work of https://github.com/gmhafiz/k8s-ha. Thank you for your great effort!

This project provides complete infrastructure automation for deploying a 6-node Kubernetes cluster with high availability control plane, load balancing, autoscaling capabilities, and CI/CD pipeline integration.

## 📋 **Table of Contents**

- [Overview](#overview)
- [Architecture](#architecture)
- [Autoscaling Features](#autoscaling-features)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Setup Instructions](#setup-instructions)
- [Usage](#usage)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)


## 🎯 **Overview**

This project automates the deployment of:

- **3-node HA Kubernetes control plane** with etcd clustering
- **3 worker nodes** for application workloads
- **7 additional autoscaling worker nodes** for dynamic scaling
- **Load balancer** (HAProxy + Keepalived) for HA API access
- **Container runtime** (containerd) with proper configuration
- **Network plugin** (Calico CNI) for pod networking
- **Complete CI/CD pipeline** using Jenkins
- **Autoscaling capabilities** with HPA and Cluster Autoscaler


### **Key Features**

✅ **High Availability**: Multi-master control plane with automatic failover
✅ **Load Balancing**: HAProxy with health checks for API server HA
✅ **Autoscaling**: Horizontal Pod Autoscaler (HPA) and Cluster Autoscaler
✅ **Infrastructure as Code**: Terraform for consistent infrastructure provisioning
✅ **Configuration Management**: Ansible playbooks for system configuration
✅ **CI/CD Integration**: Jenkins pipeline for automated deployments
✅ **Production Ready**: Security hardening and best practices applied

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer Layer                      │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  loadbalancer1  │    │  loadbalancer2  │                │
│  │ 192.168.122.51  │    │ 192.168.122.52  │                │
│  │ HAProxy+Keepalived   │ HAProxy+Keepalived                │
│  └─────────────────┘    └─────────────────┘                │
│              │                    │                         │
│              └────────┬───────────┘                         │
│                   VIP: 192.168.122.100:6443                │
└─────────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                   Control Plane Layer                       │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐│
│  │ kcontrolplane1  │ │ kcontrolplane2  │ │ kcontrolplane3  ││
│  │192.168.122.101  │ │192.168.122.102  │ │192.168.122.103  ││
│  │   API Server    │ │   API Server    │ │   API Server    ││
│  │   etcd          │ │   etcd          │ │   etcd          ││
│  │   Scheduler     │ │   Scheduler     │ │   Scheduler     ││
│  │ Controller Mgr  │ │ Controller Mgr  │ │ Controller Mgr  ││
│  └─────────────────┘ └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                     Worker Layer                            │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐│
│  │    kworker1     │ │    kworker2     │ │    kworker3     ││
│  │192.168.122.201  │ │192.168.122.202  │ │192.168.122.203  ││
│  │     kubelet     │ │     kubelet     │ │     kubelet     ││
│  │   kube-proxy    │ │   kube-proxy    │ │   kube-proxy    ││
│  │     Calico      │ │     Calico      │ │     Calico      ││
│  └─────────────────┘ └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                  Autoscaling Layer                          │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐│
│  │    kworker4     │ │    kworker5     │ │    kworker6     ││
│  │192.168.122.204  │ │192.168.122.205  │ │192.168.122.206  ││
│  │  (Auto-scaled)  │ │  (Auto-scaled)  │ │  (Auto-scaled)  ││
│  └─────────────────┘ └─────────────────┘ └─────────────────┘│
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐│
│  │    kworker7     │ │    kworker8     │ │    kworker9     ││
│  │192.168.122.207  │ │192.168.122.208  │ │192.168.122.209  ││
│  │  (Auto-scaled)  │ │  (Auto-scaled)  │ │  (Auto-scaled)  ││
│  └─────────────────┘ └─────────────────┘ └─────────────────┘│
│  ┌─────────────────┐                                        │
│  │   kworker10     │                                        │
│  │192.168.122.210  │                                        │
│  │  (Auto-scaled)  │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Autoscaling Features**

### **Horizontal Pod Autoscaler (HPA)**
- **Automatic pod scaling** based on CPU and memory utilization
- **Custom metrics support** for application-specific scaling
- **Configurable scaling policies** with stabilization windows
- **Multiple metric types** (Resource, Object, External)

### **Cluster Autoscaler**
- **Dynamic node provisioning** based on pod scheduling requirements
- **Automatic node removal** when underutilized
- **Libvirt integration** for VM lifecycle management
- **Configurable scaling limits** (min: 3, max: 10 worker nodes)

### **Autoscaling Components**
- **Metrics Server**: Provides resource utilization metrics
- **Cluster Autoscaler**: Manages node lifecycle
- **HPA Controller**: Scales pods based on metrics
- **Autoscaling Manager**: Manual scaling operations

### **Scaling Capabilities**
- **Pod-level scaling**: 1-10 replicas per deployment
- **Node-level scaling**: 3-10 worker nodes
- **Resource-based scaling**: CPU, memory utilization
- **Time-based scaling**: Configurable delays and windows

## 🛠️ **Prerequisites**

### **Host System Requirements**

- **Operating System**: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- **CPU**: 12+ cores (recommended for autoscaling)
- **Memory**: 32GB+ RAM (recommended for autoscaling)
- **Disk**: 200GB+ free space (for additional worker nodes)
- **Network**: Internet connectivity for package downloads


### **Software Dependencies**

#### **1. KVM/libvirt Virtualization**

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# CentOS/RHEL
sudo dnf install -y qemu-kvm libvirt virt-manager bridge-utils
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
```


#### **2. Docker**

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```


#### **3. Jenkins**

```bash
# Ubuntu/Debian
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins openjdk-17-jdk

# Start Jenkins
sudo systemctl enable --now jenkins
```


#### **4. Additional Tools**

```bash
sudo apt install -y git jq wget curl unzip
```


### **Jenkins Configuration**

#### **1. Jenkins Plugins Required**

Install these plugins via Jenkins UI (Manage Jenkins → Plugins):

- Docker Pipeline
- SSH Agent
- Credentials Binding
- Git
- AnsiColor
- Timestamper


#### **2. Jenkins Credentials Setup**

Create these credentials in Jenkins (Manage Jenkins → Credentials):


| Credential ID | Type | Description |
| :-- | :-- | :-- |
| `kube-ssh-public-key` | Secret text | SSH public key content |
| `github-ssh-key` | SSH Username with private key | GitHub access key |

#### **3. Docker Configuration for Jenkins**

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo usermod -aG libvirt jenkins
sudo usermod -aG kvm jenkins

# Restart Jenkins
sudo systemctl restart jenkins
```


## 📁 **Repository Structure**

```
k8s-libvirt-cluster/
├── .gitignore                 # Git ignore patterns
├── README.md                  # This file
├── Jenkinsfile               # Jenkins pipeline definition
│
├── ansible/                  # Ansible configuration management
│   ├── ansible.cfg          # Ansible configuration
│   ├── main.yaml            # Main playbook orchestrator
│   ├── vars.yaml            # Global variables
│   ├── 01-initial.yaml      # Initial system setup
│   ├── 02-packages.yaml     # Package installation
│   ├── 03-lb.yaml           # Load balancer configuration
│   ├── 04-k8s.yaml          # Kubernetes prerequisites
│   ├── 05-control-plane.yaml # Control plane setup
│   ├── 05.5-lb-full-config.yaml # LB post-cluster config
│   ├── 06-worker.yaml       # Worker node joining
│   ├── 07-k8s-config.yaml   # Final Kubernetes config
│   ├── 08-autoscaling.yaml  # Autoscaling components setup
│   └── XX-kubeadm_reset.yaml # Cluster reset playbook
│
├── terraform/               # Infrastructure as Code
│   ├── main.tf             # Main Terraform configuration
│   ├── variables.tf        # Variable definitions
│   ├── outputs.tf          # Output definitions
│   ├── autoscaler.tf       # Autoscaling infrastructure
│   ├── inventory.tpl       # Ansible inventory template
│   ├── cloud_init_user_data.tpl    # VM user data template
│   ├── cloud_init_network_config.tpl # VM network template
│   └── autoscaling-config.tpl # Autoscaling configuration template
│
├── docker/                 # Custom Docker images
│   └── Dockerfile          # Jenkins agent with K8s tools
│
└── scripts/               # Utility scripts
    ├── cleanup_vms.sh     # VM cleanup script
    ├── cleanNetwork.sh    # Network cleanup
    ├── libvirt-clean.sh   # libvirt cleanup
    ├── install-cluster-autoscaler.sh # Cluster autoscaler installation
    ├── install-hpa.sh     # HPA installation
    └── autoscaling-manager.sh # Autoscaling management script
```


## 🚀 **Setup Instructions**

### **1. Clone Repository**

```bash
git clone https://github.com/bogdandragosvasile/k8s-libvirt-cluster.git
cd k8s-libvirt-cluster
```


### **2. Generate SSH Keys**

```bash
# Generate SSH key pair for cluster access
ssh-keygen -t ed25519 -f ~/.ssh/k8s-cluster -N ""

# Display public key (copy this to Jenkins credentials)
cat ~/.ssh/k8s-cluster.pub

# Display private key (copy this to Jenkins credentials)
cat ~/.ssh/k8s-cluster
```


### **3. Configure Jenkins Credentials**

#### **Add SSH Public Key**

1. Navigate to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Kind: **Secret text**
4. Secret: `[paste public key content]`
5. ID: `kube-ssh-public-key`

#### **Add GitHub SSH Key**

1. Click **Add Credentials**
2. Kind: **SSH Username with private key**
3. Username: `git`
4. Private Key: **Enter directly** → `[paste your GitHub SSH private key]`
5. ID: `github-ssh-key`

### **4. Update Repository Configuration**

#### **Update Jenkinsfile**

Modify the git URL in the Jenkinsfile:

```groovy
git url: 'git@github.com:YOURUSERNAME/k8s-libvirt-cluster.git',
    branch: 'master',
    credentialsId: 'github-ssh-key'
```


#### **Review Terraform Variables**

Check `terraform/variables.tf` and adjust defaults if needed:

```hcl
variable "vm_memory" {
  description = "Memory for VMs in MB"
  type        = number
  default     = 4096  # Adjust based on your resources
}

variable "vm_cpu" {
  description = "Number of CPUs for VMs"
  type        = number
  default     = 2     # Adjust based on your resources
}

variable "enable_autoscaling" {
  description = "Enable autoscaling infrastructure"
  type        = bool
  default     = true
}
```


#### **Review Ansible Variables**

Check `ansible/vars.yaml` and customize:

```yaml
# Kubernetes configuration
K8S_VERSION: "1.30.1"
POD_CIDR_CALICO: "10.244.0.0/16"
VERSION_CALICO: "v3.28.0"

# Network configuration
VIRTUAL_IP: "192.168.122.100"
K8S_API_SERVER_PORT: 6443
```


### **5. Create Jenkins Pipeline**

1. **Create New Item** in Jenkins
2. Choose **Pipeline**
3. Name: `k8s-cluster-deploy`
4. **Pipeline Definition**: Pipeline script from SCM
5. **SCM**: Git
6. **Repository URL**: `https://github.com/yourusername/k8s-libvirt-cluster.git`
7. **Branch**: `master`
8. **Script Path**: `Jenkinsfile`
9. **Save**

## 🎮 **Usage**

### **Deploy Cluster**

1. Navigate to your Jenkins pipeline
2. Click **Build Now**
3. Monitor the pipeline progress through the stages:
    - ✅ Prepare Base Image
    - ✅ Setup Libvirt Pool
    - ✅ Terraform Infrastructure
    - ✅ Generate Ansible Inventory
    - ✅ Wait for SSH Connectivity
    - ✅ Run Ansible Playbook
    - ✅ Install Autoscaling Components
    - ✅ Verify Cluster

### **Access Your Cluster**

#### **From Jenkins Host**

```bash
# SSH to any control plane node
ssh -i ~/.ssh/k8s-cluster ubuntu@192.168.122.101

# Check cluster status
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```


#### **From Your Laptop**

```bash
# Copy kubeconfig from cluster
scp -i ~/.ssh/k8s-cluster ubuntu@192.168.122.101:/home/ubuntu/.kube/config ~/.kube/config

# Edit kubeconfig to use load balancer
sed -i 's/192.168.122.101/192.168.122.100/g' ~/.kube/config

# Test cluster access
kubectl get nodes
```

### **Autoscaling Operations**

#### **Install Autoscaling Components**

```bash
# Install HPA and metrics server
./scripts/install-hpa.sh

# Install cluster autoscaler
./scripts/install-cluster-autoscaler.sh
```

#### **Manual Scaling Operations**

```bash
# Check autoscaling status
./scripts/autoscaling-manager.sh status

# Scale up by adding 2 worker nodes
./scripts/autoscaling-manager.sh scale-up 2

# Scale down by removing 1 worker node
./scripts/autoscaling-manager.sh scale-down 1

# Start a specific worker node
./scripts/autoscaling-manager.sh start-node kworker4

# Stop a specific worker node
./scripts/autoscaling-manager.sh stop-node kworker4
```

#### **Monitor Autoscaling**

```bash
# Check HPA status
kubectl get hpa -A

# Monitor cluster autoscaler logs
kubectl logs -f deployment/cluster-autoscaler -n cluster-autoscaler

# Check resource utilization
kubectl top nodes
kubectl top pods -A

# View scaling events
kubectl get events --sort-by='.lastTimestamp' | grep -i scale
```

#### **Test Autoscaling**

```bash
# Create load to trigger HPA
kubectl scale deployment autoscaling-test --replicas=5 -n hpa-demo

# Create load to trigger cluster autoscaler
kubectl scale deployment autoscaling-test --replicas=20 -n hpa-demo

# Monitor scaling
watch kubectl get pods -n hpa-demo
watch kubectl get nodes
```

### **Cluster Operations**

#### **Scale Worker Nodes**

Modify `terraform/variables.tf` to add more workers:

```hcl
variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 5  # Increase from 3 to 5
}
```

Run the pipeline again to apply changes.

#### **Reset Cluster**

```bash
# Run the reset playbook manually
cd ansible
ansible-playbook -i inventory.ini XX-kubeadm_reset.yaml --extra-vars "@vars.yaml"
```


## ⚙️ **Configuration**

### **Network Configuration**

Default network settings in `terraform/main.tf`:

```hcl
# VM Network (adjust if conflicts with your network)
libvirt_network "k8s_network" {
  name      = "k8s-network"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = ["192.168.122.0/24"]
}
```


### **Resource Allocation**

Adjust VM resources in `terraform/variables.tf`:

```hcl
# Control plane nodes
variable "cp_memory" { default = 4096 }  # 4GB RAM
variable "cp_cpu" { default = 2 }        # 2 vCPUs

# Worker nodes  
variable "worker_memory" { default = 8192 }  # 8GB RAM
variable "worker_cpu" { default = 4 }        # 4 vCPUs

# Load balancer nodes
variable "lb_memory" { default = 1024 }  # 1GB RAM
variable "lb_cpu" { default = 1 }        # 1 vCPU
```


### **Kubernetes Configuration**

Customize Kubernetes settings in `ansible/vars.yaml`:

```yaml
# Kubernetes version
K8S_VERSION: "1.30.1"

# Pod network CIDR (ensure no conflicts)
POD_CIDR_CALICO: "10.244.0.0/16"

# Service network CIDR
SERVICE_CIDR: "10.96.0.0/12"

# Calico version
VERSION_CALICO: "v3.28.0"
```

### **Autoscaling Configuration**

Configure autoscaling settings:

```yaml
# HPA settings
HPA_CPU_THRESHOLD: 70
HPA_MEMORY_THRESHOLD: 80
HPA_MIN_REPLICAS: 1
HPA_MAX_REPLICAS: 10

# Cluster autoscaler settings
CLUSTER_AUTOSCALER_MIN_NODES: 3
CLUSTER_AUTOSCALER_MAX_NODES: 10
CLUSTER_AUTOSCALER_SCALE_DOWN_DELAY: 10m
CLUSTER_AUTOSCALER_SCALE_DOWN_UTILIZATION: 0.5
```


## 🔧 **Troubleshooting**

### **Common Issues**

#### **1. Pipeline Fails at SSH Connectivity**

```bash
# Check VM status
virsh list --all

# Check network connectivity
ping 192.168.122.101

# Verify SSH key permissions
ls -la ~/.ssh/k8s-cluster*
```


#### **2. Load Balancer Bootstrap Issues**

The project includes a sophisticated fix for load balancer bootstrapping:

- Uses bootstrap mode (no health checks) during cluster init
- Switches to full HA mode after cluster is ready
- Automatic failover between load balancer nodes


#### **3. Worker Nodes Not Joining**

```bash
# Check token validity on control plane
sudo kubeadm token list

# Generate new token if expired
sudo kubeadm token create --print-join-command

# Check worker node logs
sudo journalctl -u kubelet -f
```


#### **4. Certificate Issues**

```bash
# Verify API server certificates include load balancer IP
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A1 "Subject Alternative Name"
```


#### **5. Autoscaling Issues**

```bash
# Check metrics server status
kubectl get pods -n kube-system | grep metrics-server

# Check cluster autoscaler logs
kubectl logs -f deployment/cluster-autoscaler -n cluster-autoscaler

# Verify HPA configuration
kubectl describe hpa -A

# Check resource metrics
kubectl top nodes
kubectl top pods -A
```


### **Debugging Commands**

#### **Check Infrastructure**

```bash
# Terraform state
cd terraform
terraform show
terraform output

# libvirt VMs
virsh list --all
virsh net-list --all
```


#### **Check Cluster Health**

```bash
# Node status
kubectl get nodes -o wide

# Pod status  
kubectl get pods --all-namespaces

# Cluster info
kubectl cluster-info

# Component status
kubectl get componentstatuses
```


#### **Check Services**

```bash
# On any node
sudo systemctl status kubelet
sudo systemctl status containerd

# On load balancer nodes
sudo systemctl status haproxy
sudo systemctl status keepalived
```


#### **Check Autoscaling**

```bash
# HPA status
kubectl get hpa -A

# Cluster autoscaler status
kubectl get pods -n cluster-autoscaler

# Scaling events
kubectl get events --sort-by='.lastTimestamp' | grep -i scale

# Resource utilization
kubectl top nodes
kubectl top pods -A
```


### **Log Locations**

- **Jenkins logs**: Jenkins UI → Build → Console Output
- **Ansible logs**: Captured in Jenkins pipeline output
- **Terraform logs**: Set `TF_LOG=DEBUG` environment variable
- **Kubernetes logs**: `/var/log/pods/` on each node
- **kubelet logs**: `sudo journalctl -u kubelet`
- **Autoscaler logs**: `kubectl logs -f deployment/cluster-autoscaler -n cluster-autoscaler`


## 🤝 **Contributing**

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 **License**

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 **Acknowledgments**

- Kubernetes community for excellent documentation
- HashiCorp for Terraform
- Red Hat for Ansible
- Jenkins community for pipeline capabilities
- Calico project for networking
- Hafiz Shafruddin for his great and inspiring effort

***

**🎉 Happy Kubernetes Clustering with Autoscaling!**

For questions or issues, please open a GitHub issue or contribute to the project.
