version: 2
ethernets:
    ens3:
        dhcp4: false
        addresses: [${ip}/24]
        gateway4: ${gateway}
        nameservers:
            addresses: [${dns}]
