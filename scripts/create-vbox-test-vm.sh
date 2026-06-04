#!/bin/bash
set -euo pipefail

VM_DISK_SIZE_MB=${VM_DISK_SIZE_MB:-32768}
VM_MEMORY_MB=${VM_MEMORY_MB:-4096}
VM_CPUS=${VM_CPUS:-2}
ISO_DOWNLOAD_DIR=${ISO_DOWNLOAD_DIR:-$HOME/Downloads/endeavouros}
ENDEAVOUROS_MIRROR_INDEX_URL=${ENDEAVOUROS_MIRROR_INDEX_URL:-https://mirror.rznet.fr/endeavouros/iso/}
START_VM=0
START_MODE=gui
FORCE_RECREATE=0
ISO_PATH=
VM_NAME=i3-setup-test

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/create-vbox-test-vm.sh [--force] [--start] [--headless] [--iso-dir /path/to/dir] [--vm-name name] [iso-path]

Environment overrides:
  VM_DISK_SIZE_MB   Default: 32768
  VM_MEMORY_MB      Default: 4096
  VM_CPUS           Default: 2
  ISO_DOWNLOAD_DIR  Default: ~/Downloads/endeavouros
EOF
}

log() {
  printf '%s\n' "$1" >&2
}

delete_existing_vm() {
  local vm_name=$1

  if VBoxManage list runningvms | grep -Fq "\"$vm_name\""; then
    VBoxManage controlvm "$vm_name" poweroff
  fi

  VBoxManage unregistervm "$vm_name" --delete
}

resolve_latest_iso_url() {
  command -v curl >/dev/null 2>&1 || die "curl is required to download the latest ISO"

  local iso_name iso_url
  iso_name=$(curl -fsSL "$ENDEAVOUROS_MIRROR_INDEX_URL" | grep -oE 'EndeavourOS_[A-Za-z0-9.-]+\.iso' | sort -Vu | tail -n 1)
  iso_url="${ENDEAVOUROS_MIRROR_INDEX_URL}${iso_name}"
  [ -n "$iso_name" ] || die "Could not determine the latest EndeavourOS ISO name"
  [ -n "$iso_url" ] || die "Could not determine the latest EndeavourOS ISO URL"
  printf '%s\n' "$iso_url"
}

resolve_checksum_url() {
  local iso_url=$1
  local checksum_url

  for suffix in .sha512 .sha512sum; do
    checksum_url="${iso_url}${suffix}"
    if curl -fsI "$checksum_url" >/dev/null 2>&1; then
      printf '%s\n' "$checksum_url"
      return
    fi
  done

  die "Could not determine checksum URL for $iso_url"
}

ensure_latest_iso_downloaded() {
  local iso_dir=$1
  local latest_url latest_file target_path checksum_url checksum_path checksum_name existing_iso

  latest_url=$(resolve_latest_iso_url)
  checksum_url=$(resolve_checksum_url "$latest_url")
  latest_file=$(basename -- "$latest_url")
  target_path="$iso_dir/$latest_file"
  checksum_path="$iso_dir/$(basename -- "$checksum_url")"
  checksum_name=$(basename -- "$checksum_path")

  mkdir -p "$iso_dir"

  log "Refreshing checksum for latest EndeavourOS ISO"
  curl -fL --output "$checksum_path" "$checksum_url"

  if [ -f "$target_path" ]; then
    if (cd "$iso_dir" && sha512sum -c "$checksum_name" >/dev/null); then
      log "Using cached latest ISO: $target_path"
      printf '%s\n' "$target_path"
      return
    fi

    log "Cached ISO failed checksum verification, redownloading"
    rm -f "$target_path"
  fi

  existing_iso=$(printf '%s\n' "$iso_dir"/EndeavourOS_*.iso | grep -v '\*' || true)
  if [ -n "$existing_iso" ]; then
    log "Removing old cached ISO(s) from $iso_dir"
    rm -f "$iso_dir"/EndeavourOS_*.iso
  fi

  log "Downloading latest EndeavourOS ISO"
  log "Source: $latest_url"
  curl -fL --output "$target_path" "$latest_url"

  (cd "$iso_dir" && sha512sum -c "$checksum_name" >/dev/null) || die "Downloaded ISO failed checksum verification"
  printf '%s\n' "$target_path"
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
    --iso-dir)
      shift
      [ "$#" -gt 0 ] || die "--iso-dir requires a directory path"
      ISO_DOWNLOAD_DIR=$1
      ;;
    --vm-name)
      shift
      [ "$#" -gt 0 ] || die "--vm-name requires a VM name"
      VM_NAME=$1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -* )
      die "Unknown option: $1"
      ;;
    *)
      if [ -z "$ISO_PATH" ]; then
        ISO_PATH=$1
      else
        die "Too many positional arguments; use --vm-name for a custom VM name"
      fi
      ;;
  esac
  shift
done

command -v VBoxManage >/dev/null 2>&1 || die "VBoxManage is required"

if [ -z "$ISO_PATH" ]; then
  ISO_PATH=$(ensure_latest_iso_downloaded "$ISO_DOWNLOAD_DIR")
elif [ -d "$ISO_PATH" ]; then
  ISO_PATH=$(ensure_latest_iso_downloaded "$ISO_PATH")
fi

[ -f "$ISO_PATH" ] || die "ISO not found: $ISO_PATH"

if VBoxManage list vms | grep -Fq "\"$VM_NAME\""; then
  if [ "$FORCE_RECREATE" -eq 1 ]; then
    delete_existing_vm "$VM_NAME"
  else
    die "VirtualBox VM already exists: $VM_NAME (use --force to recreate it)"
  fi
fi

VM_BASE_DIR=${HOME}/VirtualBox\ VMs
VM_DIR="$VM_BASE_DIR/$VM_NAME"
DISK_PATH="$VM_DIR/$VM_NAME.vdi"

mkdir -p "$VM_DIR"

VBoxManage createvm --name "$VM_NAME" --ostype ArchLinux_64 --register
VBoxManage modifyvm "$VM_NAME" \
  --memory "$VM_MEMORY_MB" \
  --cpus "$VM_CPUS" \
  --vram 32 \
  --audio-enabled off \
  --graphicscontroller vmsvga \
  --nic1 nat \
  --clipboard-mode bidirectional \
  --draganddrop bidirectional

VBoxManage createmedium disk --filename "$DISK_PATH" --size "$VM_DISK_SIZE_MB" --format VDI
VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$DISK_PATH"
VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide
VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"

printf 'Created VM: %s\n' "$VM_NAME"
printf 'Disk: %s\n' "$DISK_PATH"
printf 'ISO: %s\n' "$ISO_PATH"
printf 'Start it with: VBoxManage startvm %q\n' "$VM_NAME"

if [ "$START_VM" -eq 1 ]; then
  VBoxManage startvm "$VM_NAME" --type "$START_MODE"
fi
