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
  sudo pacman -S --needed --noconfirm "${PACKAGE_LIST[@]}"
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
  preflight
  log "Detected distro: $DISTRO"
  install_bootstrap_packages
  install_official_packages
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
