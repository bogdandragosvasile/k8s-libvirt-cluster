#!/bin/bash
# Script to reset networking changes on Ubuntu host with Libvirt
# Run as root (sudo -i) or with sudo. Reboots at the end.
# Backup important configs before running!

set -e  # Exit on error

echo "Step 1: Disable IP Forwarding"
sysctl -w net.ipv4.ip_forward=0
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
sysctl -p
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "0" ]; then
  echo "Error: IP forwarding not disabled"
  exit 1
fi
echo "IP forwarding disabled."

echo "Step 2: Flush iptables Rules"
systemctl stop docker libvirtd || true  # Stop services to release chains
iptables -t nat -F
iptables -F
iptables -X
iptables -t nat -X
netfilter-persistent save || true  # Persist if installed
systemctl start docker libvirtd || true  # Restart services
echo "iptables flushed."

echo "Step 3: Reset UFW"
ufw reset --force || true  # Force reset, deletes all rules
ufw enable
ufw reload
echo "UFW reset to defaults."

echo "Step 4: Restart Libvirt Network"
virsh net-destroy default || true
virsh net-start default || true
echo "Libvirt default network restarted."

echo "Rebooting to apply changes..."
reboot
