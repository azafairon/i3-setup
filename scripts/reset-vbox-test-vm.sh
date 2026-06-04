#!/bin/bash
set -euo pipefail

VM_NAME=${1:-i3-setup-test}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

command -v VBoxManage >/dev/null 2>&1 || die "VBoxManage is required"

if ! VBoxManage list vms | grep -Fq "\"$VM_NAME\""; then
  die "VirtualBox VM does not exist: $VM_NAME"
fi

if VBoxManage list runningvms | grep -Fq "\"$VM_NAME\""; then
  VBoxManage controlvm "$VM_NAME" poweroff
fi

VBoxManage unregistervm "$VM_NAME" --delete
printf 'Deleted VM: %s\n' "$VM_NAME"
