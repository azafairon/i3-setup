#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$0")")
PACKAGES_FILE="$SCRIPT_DIR/packages"
AUR_PACKAGES_FILE="$SCRIPT_DIR/packages-aur"
RESOURCES_DIR="$SCRIPT_DIR/resources"
BACKUP_DIR="$HOME/.i3-setup-backups/$(date +%Y%m%d-%H%M%S)"
SYSTEM_BACKUP_DIR="/var/backups/i3-setup/$(date +%Y%m%d-%H%M%S)"
WALLPAPER_TARGET="/usr/share/backgrounds/i3-setup-wallpaper.jpg"
OH_MY_ZSH_REPO="https://github.com/ohmyzsh/ohmyzsh.git"
OH_MY_ZSH_COMMIT="70ad5e3df8f7bed68aa6672029496926e632aedd"

BACKUP_CREATED=0
SAFE_GRAPHICS=0
VIRT_TYPE=none
INTERACTIVE=0
DRIVER_PACKAGES=()
GPU_VENDORS=()
GPU_NOTICES=()
KERNEL_PACKAGES=()
NVIDIA_PROMPT_HANDLED=0

log() {
  printf '\n[%s] %s\n' "i3-setup" "$1"
}

die() {
  printf '\n[%s] ERROR: %s\n' "i3-setup" "$1" >&2
  exit 1
}

require_file() {
  [ -e "$1" ] || die "Missing required path: $1"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --safe-graphics|--vm-safe)
        SAFE_GRAPHICS=1
        ;;
      -h|--help)
        cat <<'EOF'
Usage:
  ./install.sh [--safe-graphics]

Options:
  --safe-graphics, --vm-safe
      Use a safer graphics profile for VMs and weak/unsupported GPU paths.
      This disables picom autostart and uses an opaque Alacritty config.
EOF
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
    shift
  done

  if [ -t 0 ]; then
    INTERACTIVE=1
  fi
}

prompt_yes_no() {
  local prompt=$1
  local default_answer=$2
  local reply

  if [ "$INTERACTIVE" -ne 1 ]; then
    [ "$default_answer" = "yes" ]
    return
  fi

  while true; do
    if [ "$default_answer" = "yes" ]; then
      printf '%s [Y/n] ' "$prompt"
    else
      printf '%s [y/N] ' "$prompt"
    fi
    read -r reply
    case ${reply:-} in
      [Yy]) return 0 ;;
      [Nn]) return 1 ;;
      "") [ "$default_answer" = "yes" ] && return 0 || return 1 ;;
    esac
  done
}

append_driver_package() {
  local pkg=$1
  local existing
  for existing in "${DRIVER_PACKAGES[@]:-}"; do
    [ "$existing" != "$pkg" ] || return
  done
  DRIVER_PACKAGES+=("$pkg")
}

append_gpu_notice() {
  local notice=$1
  local existing
  for existing in "${GPU_NOTICES[@]:-}"; do
    [ "$existing" != "$notice" ] || return
  done
  GPU_NOTICES+=("$notice")
}

detect_kernel_packages() {
  local pkg

  command -v pacman >/dev/null 2>&1 || return

  while read -r pkg; do
    [ -n "$pkg" ] || continue
    KERNEL_PACKAGES+=("$pkg")
  done < <(pacman -Qq 2>/dev/null | rg '^(linux|linux-lts|linux-zen|linux-hardened|linux-rt|linux-rt-lts)$' || true)
}

configure_nvidia_packages() {
  local kernel
  local default_answer=yes
  local nvidia_packages=()
  local needs_dkms=0

  for kernel in "${KERNEL_PACKAGES[@]:-}"; do
    case "$kernel" in
      linux)
        nvidia_packages+=("nvidia-open")
        ;;
      linux-lts)
        nvidia_packages+=("nvidia-open-lts")
        ;;
      linux-zen|linux-hardened|linux-rt|linux-rt-lts)
        needs_dkms=1
        ;;
    esac
  done

  NVIDIA_PROMPT_HANDLED=1

  if [ "${#nvidia_packages[@]}" -gt 0 ]; then
    append_driver_package nvidia-utils
    local pkg
    for pkg in "${nvidia_packages[@]}"; do
      append_driver_package "$pkg"
    done
  fi

  if [ "$needs_dkms" -eq 1 ]; then
    append_gpu_notice "NVIDIA detected with non-default kernel(s): install nvidia-open-dkms and the matching kernel headers manually if you want NVIDIA support on those kernels."
  fi

  if [ "${#nvidia_packages[@]}" -eq 0 ] && [ "$needs_dkms" -eq 0 ]; then
    append_gpu_notice "NVIDIA detected: no supported kernel package was detected automatically; choose the matching NVIDIA package manually after install."
  fi

  if [ "${#nvidia_packages[@]}" -gt 0 ] && ! prompt_yes_no "Install recommended NVIDIA packages for detected kernels: ${DRIVER_PACKAGES[*]}" "$default_answer"; then
    local filtered_packages=()
    local pkg
    for pkg in "${DRIVER_PACKAGES[@]}"; do
      case "$pkg" in
        nvidia-utils|nvidia-open|nvidia-open-lts) ;;
        *) filtered_packages+=("$pkg") ;;
      esac
    done
    DRIVER_PACKAGES=("${filtered_packages[@]}")
  fi
}

read_package_list() {
  local file=$1
  mapfile -t PACKAGE_LIST < <(grep -vE '^[[:space:]]*($|#)' "$file")
}

run_if_command_exists() {
  local cmd=$1
  shift
  if command -v "$cmd" >/dev/null 2>&1; then
    "$@"
  fi
}

ensure_backup_dir() {
  if [ "$BACKUP_CREATED" -eq 0 ]; then
    mkdir -p "$BACKUP_DIR"
    BACKUP_CREATED=1
    log "Backing up replaced files into $BACKUP_DIR"
  fi
}

backup_target() {
  local target=$1
  if [ -e "$target" ] || [ -L "$target" ]; then
    ensure_backup_dir
    local relative=${target#"$HOME"/}
    local backup_path="$BACKUP_DIR/$relative"
    mkdir -p "$(dirname -- "$backup_path")"
    cp -a "$target" "$backup_path"
  fi
}

install_file_with_backup() {
  local source=$1
  local target=$2
  if [ -e "$target" ] || [ -L "$target" ]; then
    backup_target "$target"
    rm -rf "$target"
  fi
  mkdir -p "$(dirname -- "$target")"
  cp -a "$source" "$target"
}

install_system_file_with_backup() {
  local source=$1
  local target=$2

  if sudo test -e "$target" || sudo test -L "$target"; then
    sudo mkdir -p "$SYSTEM_BACKUP_DIR/$(dirname -- "$target")"
    sudo cp -a "$target" "$SYSTEM_BACKUP_DIR/$target"
  fi

  sudo install -Dm644 "$source" "$target"
}

copy_tree_contents() {
  local source_dir=$1
  local target_dir=$2
  mkdir -p "$target_dir"

  local entry
  for entry in "$source_dir"/* "$source_dir"/.[!.]* "$source_dir"/..?*; do
    [ -e "$entry" ] || continue
    install_file_with_backup "$entry" "$target_dir/$(basename -- "$entry")"
  done
}

detect_distro() {
  require_file /etc/os-release
  # shellcheck disable=SC1091
  source /etc/os-release
  case "${ID:-}" in
    arch|endeavouros)
      DISTRO=${ID}
      ;;
    *)
      case " ${ID_LIKE:-} " in
        *" arch "*)
          DISTRO=${ID:-arch}
          ;;
        *)
          die "Unsupported distro: ${PRETTY_NAME:-unknown}"
          ;;
      esac
      ;;
  esac
}

detect_virtualization() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || true)
    VIRT_TYPE=${VIRT_TYPE:-none}
  fi
}

detect_gpu_vendors() {
  local vendor
  local seen=()
  local path

  for path in /sys/class/drm/card*/device/vendor; do
    [ -r "$path" ] || continue
    vendor=$(tr '[:upper:]' '[:lower:]' < "$path")
    case "$vendor" in
      0x10de) vendor=nvidia ;;
      0x1002|0x1022) vendor=amd ;;
      0x8086) vendor=intel ;;
      0x80ee) vendor=virtualbox ;;
      0x15ad) vendor=vmware ;;
      0x1af4) vendor=virtio ;;
      *) vendor=unknown ;;
    esac

    case " ${seen[*]:-} " in
      *" $vendor "*) ;;
      *)
        seen+=("$vendor")
        GPU_VENDORS+=("$vendor")
        ;;
    esac
  done

  if [ "${#GPU_VENDORS[@]}" -eq 0 ] && [ "$VIRT_TYPE" != "none" ]; then
    GPU_VENDORS+=("$VIRT_TYPE")
  fi
}

configure_graphics_profile() {
  local default_mode=no

  case "$VIRT_TYPE" in
    oracle|virtualbox|vmware|qemu|kvm)
      default_mode=yes
      ;;
  esac

  if prompt_yes_no "Use safe graphics profile" "$default_mode"; then
    SAFE_GRAPHICS=1
  fi
}

configure_driver_packages() {
  local vendor
  local default_answer=no

  [ "${#GPU_VENDORS[@]}" -gt 0 ] || return

  for vendor in "${GPU_VENDORS[@]}"; do
    case "$vendor" in
      nvidia)
        configure_nvidia_packages
        ;;
      amd)
        append_gpu_notice "AMD detected: mesa is already installed; add vulkan-radeon later only if you need Vulkan explicitly."
        ;;
      intel)
        append_gpu_notice "Intel detected: mesa is already installed; add vulkan-intel later only if you need Vulkan explicitly."
        ;;
      virtualbox|oracle)
        append_driver_package virtualbox-guest-utils
        default_answer=yes
        ;;
      vmware)
        append_driver_package open-vm-tools
        default_answer=yes
        ;;
      virtio|kvm|qemu)
        append_driver_package qemu-guest-agent
        default_answer=yes
        ;;
    esac
  done

  if [ "${#GPU_NOTICES[@]}" -gt 0 ]; then
    local notice
    for notice in "${GPU_NOTICES[@]}"; do
      log "$notice"
    done
  fi

  [ "${#DRIVER_PACKAGES[@]}" -gt 0 ] || return

  if [ "$NVIDIA_PROMPT_HANDLED" -eq 1 ] && [ "${#DRIVER_PACKAGES[@]}" -le 2 ]; then
    return
  fi

  if ! prompt_yes_no "Install recommended detected graphics/guest packages: ${DRIVER_PACKAGES[*]}" "$default_answer"; then
    DRIVER_PACKAGES=()
  fi
}

preflight() {
  [ "$(id -u)" -ne 0 ] || die "Run this script as your normal user, not root"
  command -v sudo >/dev/null 2>&1 || die "sudo is required"
  command -v pacman >/dev/null 2>&1 || die "pacman is required"

  require_file "$PACKAGES_FILE"
  require_file "$AUR_PACKAGES_FILE"
  require_file "$RESOURCES_DIR"

  log "Checking sudo access"
  sudo -v

  if command -v curl >/dev/null 2>&1; then
    log "Checking network access"
    curl -fsI https://archlinux.org >/dev/null || die "Internet access is required"
  fi
}

install_bootstrap_packages() {
  log "Installing bootstrap packages"
  sudo pacman -S --needed --noconfirm base-devel git curl
}

install_official_packages() {
  log "Installing official packages"
  read_package_list "$PACKAGES_FILE"
  if [ "${#DRIVER_PACKAGES[@]}" -gt 0 ]; then
    PACKAGE_LIST+=("${DRIVER_PACKAGES[@]}")
  fi
  sudo pacman -S --needed --noconfirm "${PACKAGE_LIST[@]}"
}

install_virtualization_packages() {
  :
}

bootstrap_yay_if_needed() {
  if command -v yay >/dev/null 2>&1; then
    return
  fi

  log "Bootstrapping yay"
  local build_dir
  build_dir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (
    cd "$build_dir/yay"
    makepkg -si --noconfirm
  )
  rm -rf "$build_dir"
}

install_aur_packages() {
  log "Installing AUR packages"
  read_package_list "$AUR_PACKAGES_FILE"
  yay -S --needed --noconfirm "${PACKAGE_LIST[@]}"
}

install_user_configs() {
  log "Installing user config files"
  copy_tree_contents "$RESOURCES_DIR/.config" "$HOME/.config"
  copy_tree_contents "$RESOURCES_DIR/.icons" "$HOME/.icons"
  copy_tree_contents "$RESOURCES_DIR/.local" "$HOME/.local"

  install_file_with_backup "$RESOURCES_DIR/.Xresources" "$HOME/.Xresources"
  install_file_with_backup "$RESOURCES_DIR/.zshrc" "$HOME/.zshrc"
  install_file_with_backup "$RESOURCES_DIR/.bashrc" "$HOME/.bashrc"
  install_file_with_backup "$RESOURCES_DIR/.profile" "$HOME/.profile"
  install_file_with_backup "$RESOURCES_DIR/.gtkrc-2.0" "$HOME/.gtkrc-2.0"

  if [ "$SAFE_GRAPHICS" -eq 1 ]; then
    log "Applying safe graphics profile"
    install_file_with_backup "$RESOURCES_DIR/.config/alacritty/alacritty-safe.toml" "$HOME/.config/alacritty/alacritty.toml"
    install_file_with_backup "$RESOURCES_DIR/.config/i3/config-safe" "$HOME/.config/i3/config"
  fi
}

install_system_configs() {
  log "Installing system config files"
  install_system_file_with_backup "$RESOURCES_DIR/etc/lightdm/lightdm.conf" /etc/lightdm/lightdm.conf
  install_system_file_with_backup "$RESOURCES_DIR/etc/lightdm/slick-greeter.conf" /etc/lightdm/slick-greeter.conf
  install_system_file_with_backup "$RESOURCES_DIR/wallpaper.jpg" "$WALLPAPER_TARGET"
}

install_wallpaper() {
  log "Installing wallpaper"
  run_if_command_exists xdg-user-dirs-update xdg-user-dirs-update
  mkdir -p "$HOME/Pictures"
  cp -f "$RESOURCES_DIR/wallpaper.jpg" "$HOME/Pictures/wallpaper.jpg"
  if command -v feh >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    feh --bg-fill "$HOME/Pictures/wallpaper.jpg" || true
  fi
}

install_oh_my_zsh() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing oh-my-zsh"
    git clone "$OH_MY_ZSH_REPO" "$HOME/.oh-my-zsh"
    (
      cd "$HOME/.oh-my-zsh"
      git checkout --quiet "$OH_MY_ZSH_COMMIT"
    )
  fi

  mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
  ln -sfn /usr/share/zsh/plugins/zsh-syntax-highlighting "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  ln -sfn /usr/share/zsh/plugins/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
}

enable_services() {
  log "Enabling system services"
  sudo systemctl enable NetworkManager.service
  sudo systemctl enable lightdm.service

  case "$VIRT_TYPE" in
    oracle|virtualbox)
      if pacman -Q virtualbox-guest-utils >/dev/null 2>&1; then
        sudo systemctl enable vboxservice.service
      fi
      ;;
    vmware)
      if pacman -Q open-vm-tools >/dev/null 2>&1; then
        sudo systemctl enable vmtoolsd.service
      fi
      ;;
    qemu|kvm|virtio)
      if pacman -Q qemu-guest-agent >/dev/null 2>&1; then
        sudo systemctl enable qemu-guest-agent.service
      fi
      ;;
  esac
}

change_default_shell() {
  local zsh_path
  zsh_path=$(command -v zsh)
  if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]; then
    log "Changing default shell to zsh"
    sudo chsh -s "$zsh_path" "$USER"
  fi
}

verify_commands() {
  local missing=()
  local commands=(
    alacritty autorandr blurlock code copyq dunst feh fzf google-chrome-stable i3exit
    jgmenu_run ksnip lightdm nm-applet nvim pavucontrol pcmanfm picom rofi volumeicon
    xautolock xfce4-power-manager yay zsh
  )
  local cmd
  for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ "${#missing[@]}" -ne 0 ]; then
    die "Missing expected commands after install: ${missing[*]}"
  fi
}

postflight_checks() {
  log "Running post-install checks"
  verify_commands
  [ -f "$HOME/.config/i3/config" ] || die "Missing i3 config after install"
  sudo systemctl is-enabled lightdm.service >/dev/null 2>&1 || die "lightdm service is not enabled"
  sudo systemctl is-enabled NetworkManager.service >/dev/null 2>&1 || die "NetworkManager service is not enabled"
}

main() {
  parse_args "$@"
  detect_distro
  detect_virtualization
  detect_kernel_packages
  detect_gpu_vendors
  preflight
  log "Detected distro: $DISTRO"
  log "Detected virtualization: $VIRT_TYPE"
  if [ "${#GPU_VENDORS[@]}" -gt 0 ]; then
    log "Detected graphics: ${GPU_VENDORS[*]}"
  fi
  configure_graphics_profile
  configure_driver_packages
  install_bootstrap_packages
  install_official_packages
  install_virtualization_packages
  bootstrap_yay_if_needed
  install_aur_packages
  install_user_configs
  install_system_configs
  install_wallpaper
  install_oh_my_zsh
  enable_services
  change_default_shell
  postflight_checks
  log "Install complete"
}

main "$@"
