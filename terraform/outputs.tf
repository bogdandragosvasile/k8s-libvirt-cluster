# output "vm_ips" {
#   value = [for vm in libvirt_domain.vms : vm.network_interface[0].addresses[0]]
# }

# output "ansible_inventory_path" {
#   value = "${path.module}/../ansible/inventory.ini"
# }
