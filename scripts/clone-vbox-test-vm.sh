#!/bin/bash
set -euo pipefail

BASE_VM_NAME=${BASE_VM_NAME:-i3-setup-base}
SNAPSHOT_NAME=${SNAPSHOT_NAME:-minimal-endeavouros}
CLONE_VM_NAME=${CLONE_VM_NAME:-i3-setup-test}
VM_VRAM_MB=${VM_VRAM_MB:-128}
START_VM=0
START_MODE=gui
FORCE_RECREATE=0

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/clone-vbox-test-vm.sh [--force] [--start] [--headless] [--base-vm name] [--snapshot name] [--vm-name name]

Environment overrides:
  BASE_VM_NAME   Default: i3-setup-base
  SNAPSHOT_NAME  Default: minimal-endeavouros
  CLONE_VM_NAME  Default: i3-setup-test
  VM_VRAM_MB     Default: 128
EOF
}

delete_existing_vm() {
  local vm_name=$1

  if VBoxManage list runningvms | grep -Fq "\"$vm_name\""; then
    VBoxManage controlvm "$vm_name" poweroff
  fi

  VBoxManage unregistervm "$vm_name" --delete
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      FORCE_RECREATE=1
      ;;
    --start)
      START_VM=1
      ;;
    --headless)
      START_VM=1
      START_MODE=headless
      ;;
    --base-vm)
      shift
      [ "$#" -gt 0 ] || die "--base-vm requires a VM name"
      BASE_VM_NAME=$1
      ;;
    --snapshot)
      shift
      [ "$#" -gt 0 ] || die "--snapshot requires a snapshot name"
      SNAPSHOT_NAME=$1
      ;;
    --vm-name)
      shift
      [ "$#" -gt 0 ] || die "--vm-name requires a VM name"
      CLONE_VM_NAME=$1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

command -v VBoxManage >/dev/null 2>&1 || die "VBoxManage is required"

if ! VBoxManage list vms | grep -Fq "\"$BASE_VM_NAME\""; then
  die "Base VM does not exist: $BASE_VM_NAME"
fi

if ! VBoxManage snapshot "$BASE_VM_NAME" list --machinereadable | grep -Fq "SnapshotName=\"$SNAPSHOT_NAME\""; then
  die "Snapshot '$SNAPSHOT_NAME' does not exist on VM '$BASE_VM_NAME'"
fi

if VBoxManage list vms | grep -Fq "\"$CLONE_VM_NAME\""; then
  if [ "$FORCE_RECREATE" -eq 1 ]; then
    delete_existing_vm "$CLONE_VM_NAME"
  else
    die "VirtualBox VM already exists: $CLONE_VM_NAME (use --force to recreate it)"
  fi
fi

VBoxManage clonevm "$BASE_VM_NAME" \
  --snapshot "$SNAPSHOT_NAME" \
  --options link \
  --name "$CLONE_VM_NAME" \
  --register

VBoxManage modifyvm "$CLONE_VM_NAME" \
  --vram "$VM_VRAM_MB" \
  --graphicscontroller vmsvga \
  --accelerate3d on

printf 'Created linked clone: %s\n' "$CLONE_VM_NAME"
printf 'Base VM: %s\n' "$BASE_VM_NAME"
printf 'Snapshot: %s\n' "$SNAPSHOT_NAME"
printf 'Start it with: VBoxManage startvm %q\n' "$CLONE_VM_NAME"

if [ "$START_VM" -eq 1 ]; then
  VBoxManage startvm "$CLONE_VM_NAME" --type "$START_MODE"
fi
