#!/bin/bash
set -euo pipefail

BASE_VM_NAME=${1:-i3-setup-base}
SNAPSHOT_NAME=${2:-minimal-endeavouros}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

log() {
  printf '%s\n' "$1"
}

command -v VBoxManage >/dev/null 2>&1 || die "VBoxManage is required"

if ! VBoxManage list vms | grep -Fq "\"$BASE_VM_NAME\""; then
  die "VirtualBox VM does not exist: $BASE_VM_NAME"
fi

if VBoxManage list runningvms | grep -Fq "\"$BASE_VM_NAME\""; then
  die "Power off the base VM before taking a snapshot: $BASE_VM_NAME"
fi

if VBoxManage snapshot "$BASE_VM_NAME" list --machinereadable | grep -Fq "SnapshotName=\"$SNAPSHOT_NAME\""; then
  die "Snapshot already exists: $SNAPSHOT_NAME"
fi

log "Creating snapshot '$SNAPSHOT_NAME' for VM '$BASE_VM_NAME'"
VBoxManage snapshot "$BASE_VM_NAME" take "$SNAPSHOT_NAME" --description "Minimal EndeavourOS base for i3-setup bootstrap tests"
log "Snapshot created successfully"
