# Prerequisites Setup for K8s Libvirt Cluster

This folder contains all the necessary scripts and configurations to transform a fresh Ubuntu 25.04 system into a fully functional development environment for the Kubernetes Libvirt Cluster project.

## 🎯 What This Setup Provides

### **Core Infrastructure:**
- **Libvirt/QEMU/KVM**: Full virtualization stack
- **Docker**: Container runtime and management
- **Jenkins**: CI/CD automation server with plugins
- **Kubectl**: Kubernetes command-line tool
- **Terraform**: Infrastructure as Code tool
- **Helm**: Kubernetes package manager

### **Development Tools:**
- **Git**: Version control
- **SSH**: Secure shell access
- **Python3**: Scripting and automation
- **jq**: JSON processing
- **curl**: HTTP client
- **wget**: File download utility

## 📁 Folder Structure

```
prerequisites/
├── README.md                    # This file
├── install.sh                   # Main installation script
├── scripts/
│   ├── 01-system-update.sh      # System update and basic packages
│   ├── 02-libvirt-setup.sh      # Libvirt/QEMU/KVM installation
│   ├── 03-docker-setup.sh       # Docker installation and configuration
│   ├── 04-jenkins-setup.sh      # Jenkins installation
│   ├── 05-kubernetes-tools.sh   # kubectl, helm installation
│   ├── 06-terraform-setup.sh    # Terraform installation
│   ├── 07-development-tools.sh  # Additional development tools
│   └── 08-final-config.sh       # Final system configuration
├── configs/
│   ├── libvirt/
│   │   ├── qemu.conf            # QEMU configuration
│   │   └── libvirtd.conf        # Libvirt daemon configuration
│   ├── docker/
│   │   └── daemon.json          # Docker daemon configuration
│   └── jenkins/
│       ├── jenkins.yaml         # Jenkins configuration as code
│       └── plugins.txt          # Required Jenkins plugins
├── docker/
│   └── Dockerfile               # Jenkins agent Docker image
└── jenkins/
    ├── jenkins-home/            # Jenkins home directory structure
    └── jobs/                    # Jenkins job configurations
```

## 🚀 Quick Start

### **Option 1: Automated Installation**
```bash
# Clone the repository
git clone https://github.com/bogdandragosvasile/k8s-libvirt-cluster.git
cd k8s-libvirt-cluster

# Run the main installation script
sudo ./prerequisites/install.sh
```

### **Option 2: Step-by-Step Installation**
```bash
# Run each script individually
sudo ./prerequisites/scripts/01-system-update.sh
sudo ./prerequisites/scripts/02-libvirt-setup.sh
sudo ./prerequisites/scripts/03-docker-setup.sh
sudo ./prerequisites/scripts/04-jenkins-setup.sh
sudo ./prerequisites/scripts/05-kubernetes-tools.sh
sudo ./prerequisites/scripts/06-terraform-setup.sh
sudo ./prerequisites/scripts/07-development-tools.sh
sudo ./prerequisites/scripts/08-final-config.sh
```

## 🔧 System Requirements

### **Minimum Requirements:**
- **OS**: Ubuntu 25.04 (or later)
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 50GB available space
- **CPU**: 4 cores minimum (8 cores recommended)
- **Network**: Internet connection for package downloads

### **Hardware Virtualization:**
- **VT-x/AMD-V**: Must be enabled in BIOS
- **Nested Virtualization**: Recommended for testing

## 📋 Installation Checklist

After running the installation scripts, verify the following:

### **Libvirt/KVM:**
- [ ] `virsh list --all` works
- [ ] `virsh pool-list` shows default pool
- [ ] KVM modules loaded (`lsmod | grep kvm`)

### **Docker:**
- [ ] `docker --version` shows version
- [ ] `docker run hello-world` works
- [ ] User added to docker group

### **Jenkins:**
- [ ] Jenkins service running (`systemctl status jenkins`)
- [ ] Jenkins accessible at `http://localhost:8080`
- [ ] All plugins installed successfully

### **Kubernetes Tools:**
- [ ] `kubectl version --client` works
- [ ] `helm version` shows version
- [ ] `terraform version` shows version

## 🔐 Security Considerations

### **SSH Configuration:**
- SSH keys generated and configured
- Password authentication disabled
- Root login disabled

### **Firewall:**
- UFW enabled with basic rules
- Jenkins port (8080) accessible
- SSH port (22) accessible

### **User Permissions:**
- Current user added to required groups
- Proper file permissions set
- Sudo access configured

## 🐛 Troubleshooting

### **Common Issues:**

1. **Libvirt Permission Denied:**
   ```bash
   sudo usermod -a -G libvirt $USER
   sudo usermod -a -G kvm $USER
   ```

2. **Docker Permission Denied:**
   ```bash
   sudo usermod -a -G docker $USER
   newgrp docker
   ```

3. **Jenkins Not Starting:**
   ```bash
   sudo systemctl status jenkins
   sudo journalctl -u jenkins -f
   ```

4. **KVM Not Available:**
   ```bash
   egrep -c '(vmx|svm)' /proc/cpuinfo
   lsmod | grep kvm
   ```

## 📚 Additional Resources

- [Libvirt Documentation](https://libvirt.org/docs.html)
- [Docker Documentation](https://docs.docker.com/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)

## 🤝 Contributing

When adding new prerequisites or modifying existing ones:

1. Update this README.md
2. Add appropriate error handling to scripts
3. Test on a fresh Ubuntu 25.04 installation
4. Update the installation checklist
5. Document any new dependencies

## 📄 License

This project is licensed under the MIT License - see the main repository LICENSE file for details.



