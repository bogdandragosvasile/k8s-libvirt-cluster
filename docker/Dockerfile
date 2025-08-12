# Use Ubuntu 25.04 as the base image for compatibility with your host
FROM ubuntu:25.04

# Set non-interactive mode to avoid debconf warnings
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages first (excluding Terraform)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    wget \
    ansible \
    git \
    jq \
    openssh-client \
    libvirt-clients \
    qemu-kvm \
    virtinst \
    genisoimage

# Add HashiCorp repo for Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Update package list and install Terraform
RUN apt-get update && apt-get install -y terraform

# Clean up to reduce image size
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory (optional, for Jenkins agent)
WORKDIR /workspace

# Run as root by default (matches our agent args)
USER root
