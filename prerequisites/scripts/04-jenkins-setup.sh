#!/bin/bash

# Jenkins Setup Script for K8s Libvirt Cluster
# Version: 1.0.0
# Description: Installs and configures Jenkins CI/CD server

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

# Install Java
install_java() {
    log_step "Installing Java..."
    
    # Update package list
    apt update
    
    # Install OpenJDK 17 (LTS)
    DEBIAN_FRONTEND=noninteractive apt install -y \
        openjdk-17-jdk \
        openjdk-17-jre
    
    # Set JAVA_HOME
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/environment
    echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /etc/environment
    
    # Source environment for current session
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
    export PATH=$PATH:$JAVA_HOME/bin
    
    log_success "Java installed"
}

# Add Jenkins repository
setup_jenkins_repository() {
    log_step "Setting up Jenkins repository..."
    
    # Add Jenkins GPG key
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
        /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    
    # Add Jenkins repository
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
        https://pkg.jenkins.io/debian-stable binary/ | tee \
        /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    # Update package list
    apt update
    
    log_success "Jenkins repository configured"
}

# Install Jenkins
install_jenkins() {
    log_step "Installing Jenkins..."
    
    # Install Jenkins
    DEBIAN_FRONTEND=noninteractive apt install -y jenkins
    
    log_success "Jenkins installed"
}

# Configure Jenkins
configure_jenkins() {
    log_step "Configuring Jenkins..."
    
    # Create Jenkins configuration directory
    mkdir -p /var/lib/jenkins/init.groovy.d
    
    # Create initial configuration script
    cat > /var/lib/jenkins/init.groovy.d/01-security.groovy << 'EOF'
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

// Disable Jenkins CLI
instance.getDescriptor("jenkins.CLI").get().setEnabled(false)

// Set up security
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)

// Save configuration
instance.save()
EOF

    # Create Jenkins configuration file
    cat > /etc/default/jenkins << 'EOF'
# Jenkins configuration
JENKINS_HOME=/var/lib/jenkins
JENKINS_USER=jenkins
JENKINS_GROUP=jenkins
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=8080 --httpListenAddress=0.0.0.0"
JENKINS_OPTS="--prefix=/jenkins"
JENKINS_JAVA_CMD=""
JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
JENKINS_JAVA_OPTIONS="$JENKINS_JAVA_OPTIONS -Dhudson.model.DirectoryBrowserSupport.CSP= -Dpermissive-script-security.enabled=true"
JENKINS_JAVA_OPTIONS="$JENKINS_JAVA_OPTIONS -Djenkins.security.SuspiciousRequestFilter.enabled=false"
JENKINS_JAVA_OPTIONS="$JENKINS_JAVA_OPTIONS -Djenkins.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true"
EOF

    # Set proper permissions
    chown -R jenkins:jenkins /var/lib/jenkins
    chmod -R 755 /var/lib/jenkins
    
    log_success "Jenkins configured"
}

# Start and enable Jenkins
start_jenkins() {
    log_step "Starting Jenkins service..."
    
    # Start and enable Jenkins
    systemctl enable jenkins
    systemctl start jenkins
    
    # Wait for Jenkins to start
    log_info "Waiting for Jenkins to start..."
    sleep 30
    
    # Check if Jenkins is running
    if ! systemctl is-active --quiet jenkins; then
        log_error "Jenkins failed to start"
        journalctl -u jenkins --no-pager -n 20
        return 1
    fi
    
    log_success "Jenkins service started"
}

# Configure firewall for Jenkins
configure_firewall() {
    log_step "Configuring firewall for Jenkins..."
    
    # Allow Jenkins traffic
    ufw allow 8080/tcp  # Jenkins web interface
    ufw allow 50000/tcp # Jenkins agent port
    
    log_success "Firewall configured for Jenkins"
}

# Install Jenkins plugins
install_jenkins_plugins() {
    log_step "Installing Jenkins plugins..."
    
    # Wait for Jenkins to be fully ready
    log_info "Waiting for Jenkins to be ready..."
    while ! curl -s http://localhost:8080 > /dev/null 2>&1; do
        sleep 5
    done
    
    # Install essential plugins
    local plugins=(
        "blueocean"
        "pipeline-stage-view"
        "git"
        "github"
        "docker-plugin"
        "kubernetes"
        "workflow-aggregator"
        "credentials-binding"
        "ssh-credentials"
        "plain-credentials"
        "matrix-project"
        "parameterized-trigger"
        "build-timeout"
        "timestamper"
        "ws-cleanup"
        "ansible"
        "terraform"
        "sonar"
        "jacoco"
        "cobertura"
        "htmlpublisher"
        "email-ext"
        "slack"
        "discord"
        "telegram"
        "mattermost"
        "rocketchat"
        "microsoft-teams"
        "jira"
        "confluence"
        "artifactory"
        "nexus-artifact-uploader"
        "docker-workflow"
        "docker-build-step"
        "docker-commons"
        "docker-custom-build-environment"
        "docker-pipeline"
        "docker-plugin"
        "docker-slaves"
        "docker-traceability"
        "dockerhub-notification"
        "dockerhub-trigger"
        "dockerhub-webhook"
        "dockerhub"
        "dockerhub-branch-source"
        "dockerhub-commons"
        "dockerhub-credentials"
        "dockerhub-listview-column"
        "dockerhub-parameter"
        "dockerhub-pipeline"
        "dockerhub-scm"
        "dockerhub-trigger"
        "dockerhub-webhook"
    )
    
    # Install plugins using Jenkins CLI
    for plugin in "${plugins[@]}"; do
        log_info "Installing plugin: $plugin"
        java -jar /usr/share/jenkins/jenkins.war -s http://localhost:8080/ install-plugin "$plugin" -deploy
    done
    
    # Restart Jenkins to apply plugin changes
    systemctl restart jenkins
    
    log_success "Jenkins plugins installed"
}

# Create Jenkins helper scripts
create_helper_scripts() {
    log_step "Creating Jenkins helper scripts..."
    
    # Create Jenkins management script
    cat > /usr/local/bin/jenkins-manager << 'EOF'
#!/bin/bash

# Jenkins Management Helper Script
# Usage: jenkins-manager [start|stop|restart|status|logs|backup|restore] [options]

case "$1" in
    start)
        systemctl start jenkins
        echo "Jenkins started"
        ;;
    stop)
        systemctl stop jenkins
        echo "Jenkins stopped"
        ;;
    restart)
        systemctl restart jenkins
        echo "Jenkins restarted"
        ;;
    status)
        systemctl status jenkins
        ;;
    logs)
        journalctl -u jenkins -f
        ;;
    backup)
        if [[ -z "$2" ]]; then
            echo "Usage: jenkins-manager backup <backup-dir>"
            exit 1
        fi
        mkdir -p "$2"
        tar -czf "$2/jenkins-backup-$(date +%Y%m%d-%H%M%S).tar.gz" -C /var/lib/jenkins .
        echo "Backup created in $2"
        ;;
    restore)
        if [[ -z "$2" ]]; then
            echo "Usage: jenkins-manager restore <backup-file>"
            exit 1
        fi
        systemctl stop jenkins
        tar -xzf "$2" -C /var/lib/jenkins
        chown -R jenkins:jenkins /var/lib/jenkins
        systemctl start jenkins
        echo "Backup restored from $2"
        ;;
    info)
        echo "Jenkins URL: http://localhost:8080"
        echo "Jenkins home: /var/lib/jenkins"
        echo "Jenkins logs: journalctl -u jenkins"
        echo "Jenkins user: jenkins"
        ;;
    *)
        echo "Usage: jenkins-manager [start|stop|restart|status|logs|backup|restore|info] [options]"
        echo "Commands:"
        echo "  start <dir>    - Start Jenkins"
        echo "  stop           - Stop Jenkins"
        echo "  restart        - Restart Jenkins"
        echo "  status         - Show Jenkins status"
        echo "  logs           - Show Jenkins logs"
        echo "  backup <dir>   - Create backup"
        echo "  restore <file> - Restore from backup"
        echo "  info           - Show Jenkins information"
        ;;
esac
EOF

    chmod +x /usr/local/bin/jenkins-manager
    
    # Create Jenkins health check script
    cat > /usr/local/bin/jenkins-health << 'EOF'
#!/bin/bash

# Jenkins Health Check Script

echo "=== Jenkins Health Check ==="
echo

echo "1. Jenkins service status:"
systemctl is-active jenkins
echo

echo "2. Jenkins process:"
ps aux | grep jenkins | grep -v grep
echo

echo "3. Jenkins port status:"
netstat -tlnp | grep :8080
echo

echo "4. Jenkins web interface:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:8080
echo

echo "5. Jenkins logs (last 10 lines):"
journalctl -u jenkins --no-pager -n 10
echo

echo "6. Jenkins disk usage:"
du -sh /var/lib/jenkins
echo

echo "7. Jenkins memory usage:"
ps aux | grep jenkins | grep -v grep | awk '{print "Memory: " $6 " KB"}'
EOF

    chmod +x /usr/local/bin/jenkins-health
    
    log_success "Helper scripts created"
}

# Create Jenkins API token script
create_api_token_script() {
    log_step "Creating Jenkins API token script..."
    
    # Create Python script for API token creation
    cat > /usr/local/bin/create-jenkins-token.py << 'EOF'
#!/usr/bin/env python3

import requests
import json
import sys
import time

def create_jenkins_token():
    """Create a Jenkins API token for the admin user"""
    
    jenkins_url = "http://localhost:8080"
    username = "admin"
    password = "admin"  # Default password, should be changed
    
    # Wait for Jenkins to be ready
    print("Waiting for Jenkins to be ready...")
    while True:
        try:
            response = requests.get(f"{jenkins_url}/api/json", timeout=5)
            if response.status_code == 200:
                break
        except requests.exceptions.RequestException:
            pass
        time.sleep(5)
    
    # Get CSRF crumb
    try:
        response = requests.get(f"{jenkins_url}/crumbIssuer/api/json", 
                              auth=(username, password))
        if response.status_code == 200:
            crumb_data = response.json()
            crumb = crumb_data['crumb']
            crumb_request_field = crumb_data['crumbRequestField']
        else:
            print("Failed to get CSRF crumb")
            return False
    except Exception as e:
        print(f"Error getting CSRF crumb: {e}")
        return False
    
    # Create API token
    headers = {
        crumb_request_field: crumb,
        'Content-Type': 'application/x-www-form-urlencoded'
    }
    
    data = {
        'newTokenName': 'k8s-libvirt-cluster-token',
        'Submit': 'Generate'
    }
    
    try:
        response = requests.post(f"{jenkins_url}/user/{username}/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken",
                               auth=(username, password),
                               headers=headers,
                               data=data)
        
        if response.status_code == 200:
            token_data = response.json()
            token = token_data['data']['tokenValue']
            print(f"Jenkins API token created successfully!")
            print(f"Token: {token}")
            print(f"Token name: k8s-libvirt-cluster-token")
            return True
        else:
            print(f"Failed to create token. Status code: {response.status_code}")
            return False
    except Exception as e:
        print(f"Error creating token: {e}")
        return False

if __name__ == "__main__":
    create_jenkins_token()
EOF

    chmod +x /usr/local/bin/create-jenkins-token.py
    
    log_success "API token script created"
}

# Test Jenkins installation
test_jenkins() {
    log_step "Testing Jenkins installation..."
    
    # Test Jenkins service
    if ! systemctl is-active --quiet jenkins; then
        log_error "Jenkins service is not running"
        return 1
    fi
    
    # Test Jenkins web interface
    if ! curl -s http://localhost:8080 > /dev/null 2>&1; then
        log_error "Jenkins web interface is not accessible"
        return 1
    fi
    
    # Test Java installation
    if ! java -version > /dev/null 2>&1; then
        log_error "Java is not properly installed"
        return 1
    fi
    
    log_success "Jenkins installation test passed"
}

# Main execution
main() {
    log_step "Starting Jenkins setup..."
    
    check_root
    install_java
    setup_jenkins_repository
    install_jenkins
    configure_jenkins
    start_jenkins
    configure_firewall
    create_helper_scripts
    create_api_token_script
    test_jenkins
    
    log_success "Jenkins setup completed successfully!"
    log_info "Jenkins is available at: http://localhost:8080"
    log_info "Default credentials: admin/admin (change immediately!)"
    log_info "Helper scripts available: jenkins-manager, jenkins-health"
    log_info "To create API token: python3 /usr/local/bin/create-jenkins-token.py"
}

# Run main function
main "$@"

