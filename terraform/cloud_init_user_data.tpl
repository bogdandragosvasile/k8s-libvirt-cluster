#cloud-config
preserve_hostname: false
hostname: ${hostname}
manage_etc_hosts: true
users:
  - name: debian
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: "$6$rounds=4096$Vf8sfpKKh7vu3rTz$7e8rISQnXK0MXiHvZb2w5xn6L2/wAE6zayKpQthGIaFvLZiPIOhBQ.mEPRrtInvi6y2IkmiDyVjG.asPUP.eh0"
ssh_pwauth: True
disable_root: false
chpasswd:
  list: |
    debian:debian
  expire: false
package_update: true
package_upgrade: true
