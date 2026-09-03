#!/usr/bin/env bash
# create-vm.sh — Clone base image, create cloud-init seed ISO, define VM.
# Uses virsh define with hand-crafted XML (pc-i440fx-resolute) because
# virt-install defaults to pc-q35 which doesn't work on this host.
set -euo pipefail

VM_NAME="$1"
VCPU="$2"
MEMORY_MB="$3"
NETWORK_NAME="$4"
BASE_VOLUME="$5"
POOL_NAME="$6"
USER_DATA="$7"
NETWORK_CONFIG="$8"
POOL_PATH="${9}"
DISK_GB="${10:-}"

say()  { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
die()  { printf '\e[31m[fail]\e[0m %s\n' "$*"; exit 1; }

echo "Creating VM: ${VM_NAME} (${VCPU} vCPU, ${MEMORY_MB}MB RAM)"

# 1. Clone base image
ROOT_VOL="${VM_NAME}-root.qcow2"
if ! virsh -c qemu:///system vol-info --pool "${POOL_NAME}" "${ROOT_VOL}" >/dev/null 2>&1; then
  echo "Cloning base image -> ${ROOT_VOL}"
  virsh -c qemu:///system vol-clone --pool "${POOL_NAME}" "${BASE_VOLUME}" "${ROOT_VOL}"
  if [[ -n "${DISK_GB}" && "${DISK_GB}" -gt 0 ]]; then
    echo "Resizing root disk to ${DISK_GB}GB"
    virsh -c qemu:///system vol-resize --pool "${POOL_NAME}" "${ROOT_VOL}" "${DISK_GB}G" 2>/dev/null || \
      echo "WARN: vol-resize failed (leaving at base size)"
  fi
else
  echo "Root volume ${ROOT_VOL} already exists, skipping clone"
fi

# 2. Create cloud-init seed ISO
SEED_VOL="${VM_NAME}-seed.iso"
if ! virsh -c qemu:///system vol-info --pool "${POOL_NAME}" "${SEED_VOL}" >/dev/null 2>&1; then
  echo "Creating cloud-init seed ISO"
  SEED_DIR=$(mktemp -d)
  cp "${USER_DATA}" "${SEED_DIR}/user-data"
  echo "instance-id: ${VM_NAME}" > "${SEED_DIR}/meta-data"
  echo "local-hostname: ${VM_NAME}" >> "${SEED_DIR}/meta-data"
  if [[ "${NETWORK_CONFIG}" != "-" && -f "${NETWORK_CONFIG}" ]]; then
    cp "${NETWORK_CONFIG}" "${SEED_DIR}/network-config"
    genisoimage -output "/tmp/${SEED_VOL}" -volid cidata -joliet -rock \
      "${SEED_DIR}/user-data" "${SEED_DIR}/meta-data" "${SEED_DIR}/network-config"
  else
    genisoimage -output "/tmp/${SEED_VOL}" -volid cidata -joliet -rock \
      "${SEED_DIR}/user-data" "${SEED_DIR}/meta-data"
  fi
  ISO_SIZE=$(stat -c%s "/tmp/${SEED_VOL}")
  virsh -c qemu:///system vol-create-as "${POOL_NAME}" "${SEED_VOL}" "${ISO_SIZE}" --format raw 2>/dev/null || true
  virsh -c qemu:///system vol-upload "${SEED_VOL}" --pool "${POOL_NAME}" "/tmp/${SEED_VOL}"
  rm -rf "${SEED_DIR}"
else
  echo "Seed ISO ${SEED_VOL} already exists, skipping"
fi

# 3. Define VM with virsh define (not virt-install)
#    Uses pc-i440fx-resolute + qemu64 CPU + IDE CDROM (proven to work on this host).
if ! virsh -c qemu:///system dominfo "${VM_NAME}" >/dev/null 2>&1; then
  echo "Defining VM ${VM_NAME}"
  ROOT_PATH="/var/lib/libvirt/images/${ROOT_VOL}"
  SEED_PATH="/var/lib/libvirt/images/${SEED_VOL}"

  virsh -c qemu:///system define /dev/stdin << XMLEOF
<domain type='kvm'>
  <name>${VM_NAME}</name>
  <maxMemory slots='16' unit='MiB'>16384</maxMemory>
  <memory unit='MiB'>${MEMORY_MB}</memory>
  <vcpu placement='static'>${VCPU}</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-resolute'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='custom' match='exact' check='none'>
    <model fallback='forbid'>qemu64</model>
  </cpu>
  <clock offset='utc'/>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='${ROOT_PATH}'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='${SEED_PATH}'/>
      <target dev='hda' bus='ide'/>
      <readonly/>
      <address type='drive' controller='0' bus='0' target='0' unit='1'/>
    </disk>
    <controller type='usb' index='0' model='piix3-uhci'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='ide' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x1'/>
    </controller>
    <interface type='network'>
      <source network='${NETWORK_NAME}'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
      </target>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
  </devices>
</domain>
XMLEOF

  say "VM ${VM_NAME} defined"
else
  echo "VM ${VM_NAME} already defined"
fi

# 4. Start VM if not running
if ! virsh -c qemu:///system dominfo "${VM_NAME}" 2>/dev/null | grep -q "State:.*running"; then
  virsh -c qemu:///system start "${VM_NAME}"
  say "VM ${VM_NAME} started"
else
  echo "VM ${VM_NAME} already running"
fi
