version: 2
ethernets:
  primary-nic:
    match:
      name: en*
    dhcp4: false
    addresses: [${ip}/24]
    gateway4: 192.168.122.1  # Libvirt default gateway
    nameservers:
      addresses: [${dns}]