#!/bin/bash
set -euo pipefail

OUTPUT_JSON_FILE="$1"
ANSIBLE_VARS_FILE="$2"

jq -r '
  def header:
    ["---",
     "# Kubernetes Configuration",
     "K8S_VERSION: 1.30.1-1.1",
     "K8S_API_SERVER_PORT: 6443",
     "",
     "# Network Configuration",
     "VIRTUAL_IP: \"192.168.122.100\"",
     "VIRTUAL_IP_PORT: 6443",
     "IP_HOST_LB1: 192.168.122.51",
     "IP_HOST_LB2: 192.168.122.52",
     "IP_HOST_CP1: 192.168.122.101",
     "IP_HOST_CP2: 192.168.122.102",
     "IP_HOST_CP3: 192.168.122.103",
     "IP_HOST_W1: 192.168.122.201",
     "",
     "# Pod Network Configuration",
     "POD_CIDR_FLANNEL: 10.244.0.0/16",
     "POD_CIDR_CALICO: 192.168.0.0/16",
     "VERSION_CALICO: \"v3.26.1\"",
     "",
     "# Authentication",
     "PASSWORD_KUBEADMIN: \"kubeadmin\"",
     "PASSWORD_KEEPALIVED: \"fW/19P0JzwNqIveyXfnhLXswVBUSFF4d3oMyVSi3g/U=\"",
     "ansible_python_interpreter: /usr/bin/python3",
     "",
     "# VM IPs (auto-updated by Jenkins):",
     "vm_ips:"];
  header,
  (.vm_ips | to_entries[] | "  \(.key): \"\(.value)\"")
' "$OUTPUT_JSON_FILE" > "$ANSIBLE_VARS_FILE"
