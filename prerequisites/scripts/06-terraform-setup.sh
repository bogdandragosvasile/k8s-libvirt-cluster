#!/bin/bash

# Terraform Setup Script for K8s Libvirt Cluster
# Version: 1.0.0
# Description: Installs and configures Terraform for infrastructure management

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Install Terraform
install_terraform() {
    log_step "Installing Terraform..."
    
    # Install required packages
    DEBIAN_FRONTEND=noninteractive apt install -y \
        curl \
        wget \
        unzip \
        gnupg \
        software-properties-common
    
    # Add HashiCorp GPG key
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    
    # Add HashiCorp repository
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    
    # Update package list
    apt update
    
    # Install Terraform
    DEBIAN_FRONTEND=noninteractive apt install -y terraform
    
    log_success "Terraform installed"
}

# Install Terraform providers
install_terraform_providers() {
    log_step "Installing Terraform providers..."
    
    # Create Terraform configuration directory
    mkdir -p ~/.terraform.d/plugins
    
    # Install libvirt provider
    local libvirt_version="0.7.1"
    local libvirt_arch="linux_amd64"
    
    curl -L "https://github.com/dmacvicar/terraform-provider-libvirt/releases/download/v${libvirt_version}/terraform-provider-libvirt-${libvirt_version}+git.${libvirt_arch}.tar.gz" | tar -xz
    mv terraform-provider-libvirt ~/.terraform.d/plugins/
    chmod +x ~/.terraform.d/plugins/terraform-provider-libvirt
    
    # Install other useful providers
    local providers=(
        "hashicorp/aws:5.0.0"
        "hashicorp/azurerm:3.0.0"
        "hashicorp/google:4.0.0"
        "hashicorp/kubernetes:2.0.0"
        "hashicorp/helm:2.0.0"
        "hashicorp/null:3.0.0"
        "hashicorp/random:3.0.0"
        "hashicorp/local:2.0.0"
        "hashicorp/template:2.0.0"
        "hashicorp/external:2.0.0"
        "hashicorp/http:3.0.0"
        "hashicorp/tls:4.0.0"
        "hashicorp/time:0.9.0"
    )
    
    for provider in "${providers[@]}"; do
        IFS=':' read -r name version <<< "$provider"
        log_info "Installing provider: $name v$version"
        terraform init -upgrade -backend=false -plugin-dir=~/.terraform.d/plugins
    done
    
    log_success "Terraform providers installed"
}

# Configure Terraform
configure_terraform() {
    log_step "Configuring Terraform..."
    
    # Create Terraform configuration directory
    mkdir -p /etc/terraform
    mkdir -p ~/.terraform.d
    
    # Create Terraform configuration file
    cat > /etc/terraform/terraform.tfrc << 'EOF'
# Terraform configuration
plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
disable_checkpoint = true

provider_installation {
  filesystem_mirror {
    path    = "/usr/share/terraform/plugins"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
EOF

    # Create plugin cache directory
    mkdir -p ~/.terraform.d/plugin-cache
    
    # Set environment variables
    echo 'export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"' >> /etc/environment
    echo 'export TF_LOG=INFO' >> /etc/environment
    echo 'export TF_LOG_PATH="/var/log/terraform.log"' >> /etc/environment
    
    # Source environment for current session
    export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
    export TF_LOG=INFO
    export TF_LOG_PATH="/var/log/terraform.log"
    
    log_success "Terraform configured"
}

# Install Terraform tools
install_terraform_tools() {
    log_step "Installing Terraform tools..."
    
    # Install tfenv (Terraform version manager)
    git clone https://github.com/tfutils/tfenv.git /opt/tfenv
    ln -sf /opt/tfenv/bin/tfenv /usr/local/bin/tfenv
    ln -sf /opt/tfenv/bin/terraform /usr/local/bin/terraform
    
    # Install tflint (Terraform linter)
    curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
    
    # Install tfsec (Terraform security scanner)
    curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
    
    # Install checkov (Infrastructure as Code security scanner)
    pip3 install checkov
    
    # Install terraform-docs
    curl -Lo ./terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v0.16.0/terraform-docs-v0.16.0-$(uname)-amd64.tar.gz
    tar -xzf terraform-docs.tar.gz
    chmod +x terraform-docs
    mv terraform-docs /usr/local/bin/
    rm -f terraform-docs.tar.gz
    
    log_success "Terraform tools installed"
}

# Create Terraform helper scripts
create_helper_scripts() {
    log_step "Creating Terraform helper scripts..."
    
    # Create Terraform management script
    cat > /usr/local/bin/terraform-manager << 'EOF'
#!/bin/bash

# Terraform Management Helper Script
# Usage: terraform-manager [init|plan|apply|destroy|validate|fmt|docs] [options]

case "$1" in
    init)
        terraform init
        ;;
    plan)
        terraform plan
        ;;
    apply)
        terraform apply -auto-approve
        ;;
    destroy)
        terraform destroy -auto-approve
        ;;
    validate)
        terraform validate
        ;;
    fmt)
        terraform fmt -recursive
        ;;
    docs)
        terraform-docs markdown table --output-file README.md --output-mode inject .
        ;;
    lint)
        tflint
        ;;
    security)
        tfsec
        ;;
    checkov)
        checkov -d .
        ;;
    workspace)
        if [[ -z "$2" ]]; then
            terraform workspace list
        else
            terraform workspace select "$2"
        fi
        ;;
    state)
        terraform state list
        ;;
    output)
        terraform output
        ;;
    *)
        echo "Usage: terraform-manager [init|plan|apply|destroy|validate|fmt|docs|lint|security|checkov|workspace|state|output] [options]"
        echo "Commands:"
        echo "  init      - Initialize Terraform"
        echo "  plan      - Show execution plan"
        echo "  apply     - Apply changes"
        echo "  destroy   - Destroy infrastructure"
        echo "  validate  - Validate configuration"
        echo "  fmt       - Format code"
        echo "  docs      - Generate documentation"
        echo "  lint      - Run tflint"
        echo "  security  - Run tfsec"
        echo "  checkov   - Run checkov"
        echo "  workspace - Manage workspaces"
        echo "  state     - List state"
        echo "  output    - Show outputs"
        ;;
esac
EOF

    chmod +x /usr/local/bin/terraform-manager
    
    # Create Terraform health check script
    cat > /usr/local/bin/terraform-health << 'EOF'
#!/bin/bash

# Terraform Health Check Script

echo "=== Terraform Health Check ==="
echo

echo "1. Terraform version:"
terraform version
echo

echo "2. Terraform providers:"
terraform providers 2>/dev/null || echo "No Terraform configuration found"
echo

echo "3. Terraform state:"
terraform state list 2>/dev/null || echo "No Terraform state found"
echo

echo "4. Installed tools:"
echo "terraform: $(which terraform 2>/dev/null || echo 'Not found')"
echo "tflint: $(which tflint 2>/dev/null || echo 'Not found')"
echo "tfsec: $(which tfsec 2>/dev/null || echo 'Not found')"
echo "checkov: $(which checkov 2>/dev/null || echo 'Not found')"
echo "terraform-docs: $(which terraform-docs 2>/dev/null || echo 'Not found')"
echo

echo "5. Terraform configuration:"
if [[ -f terraform.tf ]]; then
    echo "terraform.tf found"
    terraform validate 2>/dev/null || echo "Configuration validation failed"
else
    echo "No terraform.tf found"
fi
echo

echo "6. Terraform logs:"
if [[ -f /var/log/terraform.log ]]; then
    tail -10 /var/log/terraform.log
else
    echo "No Terraform logs found"
fi
EOF

    chmod +x /usr/local/bin/terraform-health
    
    # Create Terraform project template script
    cat > /usr/local/bin/terraform-init-project << 'EOF'
#!/bin/bash

# Terraform Project Initialization Script
# Usage: terraform-init-project <project-name>

if [[ -z "$1" ]]; then
    echo "Usage: terraform-init-project <project-name>"
    exit 1
fi

project_name="$1"
project_dir="$project_name"

# Create project directory
mkdir -p "$project_dir"
cd "$project_dir"

# Create main Terraform configuration
cat > main.tf << 'MAIN_EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Variables
variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 3
}

variable "vm_memory" {
  description = "Memory for each VM (MB)"
  type        = number
  default     = 2048
}

variable "vm_vcpu" {
  description = "Number of vCPUs for each VM"
  type        = number
  default     = 2
}

# Data sources
data "libvirt_pool" "default" {
  name = "default"
}

# Resources
resource "libvirt_volume" "vm_disk" {
  count  = var.vm_count
  name   = "vm-${count.index + 1}.qcow2"
  pool   = data.libvirt_pool.default.name
  size   = 10 * 1024 * 1024 * 1024 # 10GB
  format = "qcow2"
}

resource "libvirt_domain" "vm" {
  count  = var.vm_count
  name   = "vm-${count.index + 1}"
  memory = var.vm_memory
  vcpu   = var.vm_vcpu

  disk {
    volume_id = libvirt_volume.vm_disk[count.index].id
  }

  network_interface {
    network_name = "default"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Outputs
output "vm_ips" {
  description = "IP addresses of created VMs"
  value       = libvirt_domain.vm[*].network_interface[0].addresses[0]
}

output "vm_names" {
  description = "Names of created VMs"
  value       = libvirt_domain.vm[*].name
}
MAIN_EOF

# Create variables file
cat > variables.tf << 'VARS_EOF'
variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 3
}

variable "vm_memory" {
  description = "Memory for each VM (MB)"
  type        = number
  default     = 2048
}

variable "vm_vcpu" {
  description = "Number of vCPUs for each VM"
  type        = number
  default     = 2
}
VARS_EOF

# Create outputs file
cat > outputs.tf << 'OUTPUTS_EOF'
output "vm_ips" {
  description = "IP addresses of created VMs"
  value       = libvirt_domain.vm[*].network_interface[0].addresses[0]
}

output "vm_names" {
  description = "Names of created VMs"
  value       = libvirt_domain.vm[*].name
}
OUTPUTS_EOF

# Create terraform.tfvars
cat > terraform.tfvars << 'TFVARS_EOF'
vm_count  = 3
vm_memory = 2048
vm_vcpu   = 2
TFVARS_EOF

# Create .gitignore
cat > .gitignore << 'GITIGNORE_EOF'
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files, which are likely to contain sensitive data
*.tfvars
*.tfvars.json

# Ignore override files as they are usually used to override resources locally
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Include override files you do wish to add to version control using negated pattern
# !example_override.tf

# Include tfplan files to ignore the plan output of command: terraform plan -out=tfplan
*tfplan*

# Ignore CLI configuration files
.terraformrc
terraform.rc
GITIGNORE_EOF

# Create README
cat > README.md << 'README_EOF'
# Terraform Project: $project_name

This Terraform configuration creates virtual machines using libvirt.

## Prerequisites

- Terraform >= 1.0
- libvirt provider
- QEMU/KVM with libvirt

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. Destroy the infrastructure:
   ```bash
   terraform destroy
   ```

## Variables

- `vm_count`: Number of VMs to create (default: 3)
- `vm_memory`: Memory for each VM in MB (default: 2048)
- `vm_vcpu`: Number of vCPUs for each VM (default: 2)

## Outputs

- `vm_ips`: IP addresses of created VMs
- `vm_names`: Names of created VMs
README_EOF

echo "Terraform project '$project_name' initialized successfully!"
echo "Directory: $project_dir"
echo "Next steps:"
echo "1. cd $project_dir"
echo "2. terraform init"
echo "3. terraform plan"
echo "4. terraform apply"
EOF

    chmod +x /usr/local/bin/terraform-init-project
    
    log_success "Helper scripts created"
}

# Configure firewall for Terraform
configure_firewall() {
    log_step "Configuring firewall for Terraform..."
    
    # Terraform doesn't require specific firewall rules as it's a local tool
    # But we can add rules for any remote providers if needed
    
    log_success "Firewall configured for Terraform"
}

# Test Terraform installation
test_terraform() {
    log_step "Testing Terraform installation..."
    
    # Test Terraform version
    if ! terraform version > /dev/null 2>&1; then
        log_error "Terraform version test failed"
        return 1
    fi
    
    # Test tflint
    if ! tflint --version > /dev/null 2>&1; then
        log_error "tflint test failed"
        return 1
    fi
    
    # Test tfsec
    if ! tfsec --version > /dev/null 2>&1; then
        log_error "tfsec test failed"
        return 1
    fi
    
    # Test checkov
    if ! checkov --version > /dev/null 2>&1; then
        log_error "checkov test failed"
        return 1
    fi
    
    # Test terraform-docs
    if ! terraform-docs version > /dev/null 2>&1; then
        log_error "terraform-docs test failed"
        return 1
    fi
    
    log_success "Terraform installation test passed"
}

# Main execution
main() {
    log_step "Starting Terraform setup..."
    
    check_root
    install_terraform
    install_terraform_providers
    configure_terraform
    install_terraform_tools
    create_helper_scripts
    configure_firewall
    test_terraform
    
    log_success "Terraform setup completed successfully!"
    log_info "You can now use Terraform to manage infrastructure"
    log_info "Helper scripts available: terraform-manager, terraform-health, terraform-init-project"
    log_info "To create a new project: terraform-init-project <project-name>"
}

# Run main function
main "$@"

