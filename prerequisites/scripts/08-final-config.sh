#!/bin/bash
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

# Script information
SCRIPT_NAME="Final Configuration Setup"
SCRIPT_VERSION="1.0.0"

log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"

# Function to configure environment variables
configure_environment() {
    log_step "Configuring environment variables..."
    
    # Create environment file
    sudo tee /etc/environment.d/development.conf > /dev/null << 'EOF'
# Development Environment Configuration
export PATH="/usr/local/go/bin:$PATH"
export GOPATH="$HOME/go"
export GOROOT="/usr/local/go"
export PATH="$GOPATH/bin:$PATH"

# Kubernetes configuration
export KUBECONFIG="$HOME/.kube/config"

# Terraform configuration
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
export TF_LOG=INFO
export TF_LOG_PATH="$HOME/.terraform.log"

# Docker configuration
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Development tools
export EDITOR=vim
export VISUAL=vim
export PAGER=less

# Shell configuration
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:ll:cd:pwd:clear:history:exit"

# Color support
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# Development aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'

# Kubernetes aliases
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kctx='kubectx'
alias kns='kubens'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dimg='docker images'
alias dex='docker exec -it'
alias dlog='docker logs'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gb='git branch'
alias gco='git checkout'

# Terraform aliases
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'

# System aliases
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias clean='sudo apt-get autoremove -y && sudo apt-get autoclean'
alias ports='sudo netstat -tulpn'
alias mem='free -h'
alias disk='df -h'
alias cpu='htop'
alias temp='sensors'

# Development shortcuts
alias dev-status='dev-manager status'
alias dev-update='dev-manager update'
alias dev-clean='dev-manager clean'
alias dev-test='dev-manager test'
alias health-check='dev-check'

# Kubernetes cluster management
alias k8s-start='sudo virsh start kcontrolplane1 kcontrolplane2 kcontrolplane3 kworker1 kworker2 kworker3 loadbalancer1 loadbalancer2'
alias k8s-stop='sudo virsh shutdown kcontrolplane1 kcontrolplane2 kcontrolplane3 kworker1 kworker2 kworker3 loadbalancer1 loadbalancer2'
alias k8s-status='sudo virsh list --all'
alias k8s-reset='sudo virsh destroy kcontrolplane1 kcontrolplane2 kcontrolplane3 kworker1 kworker2 kworker3 loadbalancer1 loadbalancer2 2>/dev/null || true'

# Jenkins management
alias jenkins-status='sudo systemctl status jenkins'
alias jenkins-start='sudo systemctl start jenkins'
alias jenkins-stop='sudo systemctl stop jenkins'
alias jenkins-restart='sudo systemctl restart jenkins'
alias jenkins-logs='sudo journalctl -u jenkins -f'

# Libvirt management
alias vm-list='sudo virsh list --all'
alias vm-start='sudo virsh start'
alias vm-stop='sudo virsh shutdown'
alias vm-destroy='sudo virsh destroy'
alias vm-console='sudo virsh console'
alias vm-info='sudo virsh dominfo'
alias vm-network='sudo virsh net-list --all'
alias vm-pool='sudo virsh pool-list --all'
EOF

    # Source the environment file
    source /etc/environment.d/development.conf
    
    log_success "Environment variables configured successfully"
}

# Function to configure shell profiles
configure_shell_profiles() {
    log_step "Configuring shell profiles..."
    
    # Configure bash profile
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "source /etc/environment.d/development.conf" "$HOME/.bashrc"; then
            echo "" >> "$HOME/.bashrc"
            echo "# Development environment configuration" >> "$HOME/.bashrc"
            echo "source /etc/environment.d/development.conf" >> "$HOME/.bashrc"
        fi
    fi
    
    # Configure zsh profile
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "source /etc/environment.d/development.conf" "$HOME/.zshrc"; then
            echo "" >> "$HOME/.zshrc"
            echo "# Development environment configuration" >> "$HOME/.zshrc"
            echo "source /etc/environment.d/development.conf" >> "$HOME/.zshrc"
        fi
    fi
    
    # Create .profile if it doesn't exist
    if [[ ! -f "$HOME/.profile" ]]; then
        touch "$HOME/.profile"
    fi
    
    if ! grep -q "source /etc/environment.d/development.conf" "$HOME/.profile"; then
        echo "" >> "$HOME/.profile"
        echo "# Development environment configuration" >> "$HOME/.profile"
        echo "source /etc/environment.d/development.conf" >> "$HOME/.profile"
    fi
    
    log_success "Shell profiles configured successfully"
}

# Function to configure Git
configure_git() {
    log_step "Configuring Git..."
    
    # Set default Git configuration if not already set
    if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
        git config --global user.name "Development User"
    fi
    
    if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
        git config --global user.email "dev@localhost"
    fi
    
    # Configure Git settings
    git config --global core.editor vim
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global push.default simple
    git config --global color.ui auto
    git config --global log.decorate auto
    git config --global log.abbrevCommit true
    git config --global log.graph true
    git config --global log.oneline true
    
    # Configure Git aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.visual '!gitk'
    
    log_success "Git configured successfully"
}

# Function to configure SSH
configure_ssh() {
    log_step "Configuring SSH..."
    
    # Create SSH directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Generate SSH key if it doesn't exist
    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        log_info "Generating SSH key..."
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "development@localhost"
    fi
    
    # Configure SSH config
    cat > "$HOME/.ssh/config" << 'EOF'
# SSH Configuration for Development Environment

# Default settings
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/control-%h-%p-%r
    ControlPersist 10m

# Kubernetes cluster nodes
Host kcontrolplane1 kcontrolplane2 kcontrolplane3
    HostName %h
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host kworker1 kworker2 kworker3
    HostName %h
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host loadbalancer1 loadbalancer2
    HostName %h
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Local development
Host localhost
    HostName localhost
    User $USER
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

    chmod 600 "$HOME/.ssh/config"
    
    log_success "SSH configured successfully"
}

# Function to configure system optimizations
configure_system_optimizations() {
    log_step "Configuring system optimizations..."
    
    # Configure systemd journal
    sudo mkdir -p /etc/systemd/journald.conf.d
    sudo tee /etc/systemd/journald.conf.d/development.conf > /dev/null << 'EOF'
[Journal]
Storage=persistent
SystemMaxUse=1G
SystemKeepFree=1G
SystemMaxFileSize=100M
MaxRetentionSec=30day
EOF

    # Configure logrotate for development logs
    sudo tee /etc/logrotate.d/development > /dev/null << 'EOF'
/home/*/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}

/var/log/development/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    # Configure system limits for development
    sudo tee /etc/security/limits.d/development.conf > /dev/null << 'EOF'
# Development environment limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
* soft memlock unlimited
* hard memlock unlimited
EOF

    # Configure sysctl for development
    sudo tee /etc/sysctl.d/99-development.conf > /dev/null << 'EOF'
# Development environment sysctl settings

# File system
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Network
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535

# Virtual memory
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1
EOF

    # Apply sysctl settings
    sudo sysctl -p /etc/sysctl.d/99-development.conf
    
    log_success "System optimizations configured successfully"
}

# Function to configure development directories
configure_development_directories() {
    log_step "Configuring development directories..."
    
    # Create development directory structure
    mkdir -p "$HOME/development"
    mkdir -p "$HOME/development/projects"
    mkdir -p "$HOME/development/tools"
    mkdir -p "$HOME/development/configs"
    mkdir -p "$HOME/development/logs"
    mkdir -p "$HOME/development/backups"
    mkdir -p "$HOME/development/temp"
    
    # Create Go workspace
    mkdir -p "$HOME/go/src"
    mkdir -p "$HOME/go/bin"
    mkdir -p "$HOME/go/pkg"
    
    # Create Terraform directories
    mkdir -p "$HOME/.terraform.d/plugin-cache"
    mkdir -p "$HOME/.terraform.d/credentials"
    
    # Create Kubernetes directories
    mkdir -p "$HOME/.kube"
    
    # Create Docker directories
    mkdir -p "$HOME/.docker"
    
    # Set permissions
    chmod 755 "$HOME/development"
    chmod 755 "$HOME/go"
    
    log_success "Development directories configured successfully"
}

# Function to configure monitoring and logging
configure_monitoring() {
    log_step "Configuring monitoring and logging..."
    
    # Create log directory
    sudo mkdir -p /var/log/development
    sudo chown $USER:$USER /var/log/development
    
    # Configure logrotate for development
    sudo tee /etc/logrotate.d/development-logs > /dev/null << 'EOF'
/var/log/development/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF

    # Create system monitoring script
    sudo tee /usr/local/bin/system-monitor > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo "=== System Monitoring Report ==="
echo "Generated: $(date)"
echo

# System resources
log_info "System Resources:"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory Usage: $(free | awk '/Mem:/ {printf("%.1f%%", $3/$2*100)}')"
echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo

# Service status
log_info "Service Status:"
services=("libvirtd" "docker" "jenkins" "ssh" "ufw")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_success "$service: running"
    else
        log_error "$service: not running"
    fi
done
echo

# Network status
log_info "Network Status:"
echo "Active connections: $(ss -tuln | wc -l)"
echo "Listening ports: $(ss -tuln | grep LISTEN | wc -l)"
echo

# Docker status
if command -v docker >/dev/null 2>&1; then
    log_info "Docker Status:"
    echo "Running containers: $(docker ps --format 'table {{.Names}}' | wc -l)"
    echo "Total containers: $(docker ps -a --format 'table {{.Names}}' | wc -l)"
    echo "Images: $(docker images --format 'table {{.Repository}}' | wc -l)"
    echo
fi

# Kubernetes status
if command -v kubectl >/dev/null 2>&1; then
    log_info "Kubernetes Status:"
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
        echo "Pods: $(kubectl get pods --all-namespaces --no-headers | wc -l)"
        echo "Services: $(kubectl get services --all-namespaces --no-headers | wc -l)"
    else
        log_warning "Kubernetes cluster not accessible"
    fi
    echo
fi

# Libvirt status
if command -v virsh >/dev/null 2>&1; then
    log_info "Libvirt Status:"
    vm_count=$(sudo virsh list --all --name | grep -v "^$" | wc -l)
    running_count=$(sudo virsh list --name | grep -v "^$" | wc -l)
    echo "Total VMs: $vm_count"
    echo "Running VMs: $running_count"
    echo
fi

log_info "Monitoring report completed!"
EOF

    sudo chmod +x /usr/local/bin/system-monitor
    
    # Create system health check cron job
    (crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/system-monitor >> /var/log/development/system-monitor.log 2>&1") | crontab -
    
    log_success "Monitoring and logging configured successfully"
}

# Function to create final setup script
create_final_setup() {
    log_step "Creating final setup script..."
    
    # Create a comprehensive setup verification script
    sudo tee /usr/local/bin/setup-verification > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

echo "=== Development Environment Setup Verification ==="
echo "Date: $(date)"
echo "User: $USER"
echo "Hostname: $(hostname)"
echo

# Check system requirements
log_step "System Requirements Check"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $4}') available"
echo

# Check virtualization support
log_step "Virtualization Support Check"
if egrep -c '(vmx|svm)' /proc/cpuinfo > 0; then
    log_success "Hardware virtualization supported"
else
    log_warning "Hardware virtualization not detected"
fi

if lsmod | grep -q kvm; then
    log_success "KVM module loaded"
else
    log_error "KVM module not loaded"
fi
echo

# Check essential services
log_step "Essential Services Check"
services=("libvirtd" "docker" "jenkins" "ssh" "ufw")
for service in "${services[@]}"; do
    if systemctl is-enabled --quiet "$service"; then
        log_success "$service: enabled"
    else
        log_warning "$service: not enabled"
    fi
    
    if systemctl is-active --quiet "$service"; then
        log_success "$service: running"
    else
        log_error "$service: not running"
    fi
done
echo

# Check development tools
log_step "Development Tools Check"
tools=(
    "git:git --version"
    "docker:docker --version"
    "kubectl:kubectl version --client"
    "terraform:terraform --version"
    "helm:helm version"
    "jenkins:java -jar /usr/share/jenkins/jenkins.war --version"
    "virsh:virsh --version"
    "go:go version"
    "node:node --version"
    "npm:npm --version"
    "python3:python3 --version"
    "pip3:pip3 --version"
)

for tool_info in "${tools[@]}"; do
    tool_name=$(echo "$tool_info" | cut -d: -f1)
    version_cmd=$(echo "$tool_info" | cut -d: -f2)
    
    if command -v "$tool_name" >/dev/null 2>&1; then
        version=$($version_cmd 2>/dev/null | head -n1 || echo "version unknown")
        log_success "$tool_name: $version"
    else
        log_error "$tool_name: not installed"
    fi
done
echo

# Check network connectivity
log_step "Network Connectivity Check"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_success "Internet connectivity: OK"
else
    log_error "Internet connectivity: FAILED"
fi

if ping -c 1 google.com >/dev/null 2>&1; then
    log_success "DNS resolution: OK"
else
    log_error "DNS resolution: FAILED"
fi
echo

# Check file permissions
log_step "File Permissions Check"
if [[ -r "$HOME/.ssh/id_ed25519" ]]; then
    log_success "SSH key: accessible"
else
    log_warning "SSH key: not found or not accessible"
fi

if [[ -d "$HOME/.kube" ]]; then
    log_success "Kubernetes config directory: exists"
else
    log_warning "Kubernetes config directory: not found"
fi

if [[ -d "$HOME/go" ]]; then
    log_success "Go workspace: exists"
else
    log_warning "Go workspace: not found"
fi
echo

# Check helper scripts
log_step "Helper Scripts Check"
helper_scripts=("dev-manager" "dev-check" "system-monitor" "setup-verification")
for script in "${helper_scripts[@]}"; do
    if command -v "$script" >/dev/null 2>&1; then
        log_success "$script: available"
    else
        log_error "$script: not found"
    fi
done
echo

# Summary
log_step "Setup Verification Summary"
echo "To complete the setup, please:"
echo "1. Reboot the system to apply all changes"
echo "2. Run 'setup-verification' after reboot to confirm everything works"
echo "3. Configure your Git user information:"
echo "   git config --global user.name 'Your Name'"
echo "   git config --global user.email 'your.email@example.com'"
echo "4. Set up your SSH key for remote access if needed"
echo "5. Configure your Kubernetes cluster"
echo "6. Start using the development environment!"
echo

log_success "Setup verification completed!"
EOF

    sudo chmod +x /usr/local/bin/setup-verification
    
    log_success "Final setup script created successfully"
}

# Function to test final configuration
test_final_configuration() {
    log_step "Testing final configuration..."
    
    # Test environment variables
    if [[ -f "/etc/environment.d/development.conf" ]]; then
        log_success "Environment configuration file exists"
    else
        log_error "Environment configuration file missing"
    fi
    
    # Test helper scripts
    if command -v dev-manager >/dev/null 2>&1; then
        log_success "dev-manager script available"
    else
        log_error "dev-manager script not found"
    fi
    
    if command -v dev-check >/dev/null 2>&1; then
        log_success "dev-check script available"
    else
        log_error "dev-check script not found"
    fi
    
    if command -v system-monitor >/dev/null 2>&1; then
        log_success "system-monitor script available"
    else
        log_error "system-monitor script not found"
    fi
    
    if command -v setup-verification >/dev/null 2>&1; then
        log_success "setup-verification script available"
    else
        log_error "setup-verification script not found"
    fi
    
    # Test SSH configuration
    if [[ -f "$HOME/.ssh/config" ]]; then
        log_success "SSH configuration exists"
    else
        log_error "SSH configuration missing"
    fi
    
    # Test development directories
    if [[ -d "$HOME/development" ]]; then
        log_success "Development directory structure exists"
    else
        log_error "Development directory structure missing"
    fi
    
    log_success "Final configuration tested successfully"
}

# Main function
main() {
    log_info "Starting final configuration..."
    
    # Configure environment variables
    configure_environment
    
    # Configure shell profiles
    configure_shell_profiles
    
    # Configure Git
    configure_git
    
    # Configure SSH
    configure_ssh
    
    # Configure system optimizations
    configure_system_optimizations
    
    # Configure development directories
    configure_development_directories
    
    # Configure monitoring and logging
    configure_monitoring
    
    # Create final setup script
    create_final_setup
    
    # Test final configuration
    test_final_configuration
    
    log_success "Final configuration completed successfully!"
    log_info ""
    log_info "🎉 Development environment setup is complete!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Reboot the system to apply all changes"
    log_info "2. Run 'setup-verification' after reboot"
    log_info "3. Configure your Git user information"
    log_info "4. Set up your SSH key for remote access"
    log_info "5. Start using the development environment!"
    log_info ""
    log_info "Available commands:"
    log_info "  - dev-manager status    # Check tool status"
    log_info "  - dev-check            # Health check"
    log_info "  - system-monitor       # System monitoring"
    log_info "  - setup-verification   # Complete setup verification"
    log_info ""
    log_info "Happy coding! 🚀"
}

# Run main function
main "$@"
