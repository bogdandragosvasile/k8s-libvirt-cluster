[load_balancer]

${lb1_ip} ansible_user=ubuntu

${lb2_ip} ansible_user=ubuntu

[control_plane_init]

${cp1_ip} ansible_user=ubuntu

[control_plane_join]

${cp2_ip} ansible_user=ubuntu

${cp3_ip} ansible_user=ubuntu

[control_plane:children]

control_plane_init

control_plane_join

[workers]

${worker1_ip} ansible_user=ubuntu

${worker2_ip} ansible_user=ubuntu

${worker3_ip} ansible_user=ubuntu
