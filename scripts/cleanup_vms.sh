#!/bin/bash
# Cleanup script for Libvirt K8s cluster
# Removes all related VMs and their storage, keeps only base image
# Resets Libvirt default NAT network to factory state

set -e

# VM name patterns
VM_PATTERNS=(
  "loadbalancer1"
  "loadbalancer2"
  "kcontrolplane1"
  "kcontrolplane2"
  "kcontrolplane3"
  "kworker1"
  "kworker2"
  "kworker3"
)

# Paths and base settings
BASE_IMAGE="ubuntu-24.04-server-cloudimg-amd64.img"
IMAGES_DIR="/var/lib/libvirt/images"
LIBVIRT_DEFAULT_XML="/usr/share/libvirt/networks/default.xml"

echo "=== Stopping and undefining VMs ==="
for vm in "${VM_PATTERNS[@]}"; do
  if sudo virsh dominfo "$vm" &>/dev/null; then
    echo "Stopping VM: $vm"
    sudo virsh destroy "$vm" &>/dev/null || true
    echo "Undefining VM: $vm"
    sudo virsh undefine "$vm" --remove-all-storage &>/dev/null || true
  else
    echo "VM $vm not found, skipping."
  fi
done

echo "=== Removing leftover VM disk images (except base image) ==="
for img in "$IMAGES_DIR"/*; do
  fname=$(basename "$img")
  if [[ "$fname" != "$BASE_IMAGE" ]] && [[ -f "$img" ]]; then
    echo "Deleting disk: $fname"
    sudo rm -f "$img"
  fi
done

echo "=== Resetting Libvirt default network ==="
sudo virsh net-destroy default || true
sudo virsh net-undefine default || true
sudo virsh net-define "$LIBVIRT_DEFAULT_XML"
sudo virsh net-start default
sudo virsh net-autostart default
echo "Default network restored from: $LIBVIRT_DEFAULT_XML"

echo "=== Verifying remaining images in $IMAGES_DIR ==="
ls -lh "$IMAGES_DIR"

echo "=== Network check ==="
sudo virsh net-list --all
sudo virsh net-dumpxml default

echo "Cleanup & network reset complete.
You can now run Terraform apply or the Jenkins pipeline from a clean state."
