#!/bin/bash

set -e

echo "Stopping and undefining all VMs..."
for DOMAIN in $(virsh list --all --name | grep -v '^$'); do
  echo "Destroying $DOMAIN..."
  virsh destroy "$DOMAIN" || true
  echo "Undefining $DOMAIN..."
  virsh undefine "$DOMAIN" --nvram || true
done

echo "Destroying and undefining network 'k8s_net' (if exists)..."
virsh net-destroy k8s_net || true
virsh net-undefine k8s_net || true

echo "Deleting all QCOW2 and ISO volumes in 'default' pool..."
for VOL in $(virsh vol-list default | awk 'NR>2 {print $1}' | grep -E '\.qcow2$|\.iso$'); do
  echo "Deleting volume $VOL ..."
  virsh vol-delete "$VOL" --pool default || true
done

echo "Clean-up complete."
