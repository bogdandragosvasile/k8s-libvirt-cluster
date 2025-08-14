[load_balancer]
${lb1_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/id_ed25519
${lb2_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/id_ed25519

[control_plane_init]
${cp1_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/id_ed25519

[control_plane_join]
${cp2_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/id_ed25519
${cp3_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/id_ed25519

[control_plane:children]
control_plane_init
control_plane_join

[workers]
${worker1_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/id_ed25519
${worker2_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/id_ed25519
${worker3_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/id_ed25519
