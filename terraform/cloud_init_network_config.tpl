version: 2
ethernets:
  all-en:
    match:
      name: en*
    dhcp4: false
    addresses: [${ip}/24]
    gateway4: ${gateway}
    nameservers:
      addresses: [${dns}]
