#!/bin/bash
# Revised script to fully reset networking changes on Ubuntu host with Libvirt/Docker/UFW
# Run as root. Reboots at the end.

set -e  # Exit on error

echo "Step 1: Stop services to release rules"
systemctl stop docker libvirtd ufw || true

echo "Step 2: Disable and remove IP forwarding completely"
sysctl -w net.ipv4.ip_forward=0
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
rm -f /etc/sysctl.d/*ip_forward* || true  # Remove any service-specific files
sysctl -p
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "0" ]; then
  echo "Error: IP forwarding not disabled"
  exit 1
fi

echo "Step 3: Flush and delete all iptables rules/chains"
iptables -t nat -F
iptables -t nat -X
iptables -F
iptables -X
iptables -P FORWARD ACCEPT  # Reset policy to ACCEPT (default)
netfilter-persistent save || true  # If installed

echo "Step 4: Uninstall netfilter/iptables-persistent if present"
apt purge -y netfilter-persistent iptables-persistent || true
apt autoremove -y

echo "Step 5: Reset UFW to defaults and disable"
ufw reset --force || true
ufw disable
systemctl disable ufw || true

echo "Step 6: Prevent Libvirt from adding rules (disable NAT in default network)"
virsh net-destroy default || true
virsh net-undefine default || true
virsh net-define /usr/share/libvirt/networks/default.xml  # Restore original without custom NAT
virsh net-start default || true
virsh net-autostart default || true

echo "Step 7: Restart services with clean state"
systemctl start docker libvirtd || true

echo "Rebooting to apply all changes..."
reboot
