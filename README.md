# i3 Setup

Personal EndeavourOS bootstrap for a fresh install.

The goal is:

- install a bare EndeavourOS system
- clone this repo
- run one script
- end up with my default i3, terminal, shell, editor, and desktop setup

## What It Does

`install.sh` will:

- detect EndeavourOS or Arch-based systems
- install official packages from `packages`
- bootstrap `yay` if needed
- install AUR packages from `packages-aur`
- back up replaced user files into `~/.i3-setup-backups/<timestamp>`
- install the configs from `resources/`
- install and configure LightDM
- install the default wallpaper
- install `oh-my-zsh`
- set the default shell to `zsh`
- enable `NetworkManager` and `lightdm`
- run post-install checks for expected commands and services
- back up replaced system files under `/var/backups/i3-setup/<timestamp>`

The bootstrap intentionally pins `oh-my-zsh` to a known git commit instead of executing the remote upstream install script at install time.

Package note:

- `mesa` is installed as the baseline graphics/OpenGL stack
- the official package list uses `neovim` rather than `nvim`
- wallpaper handling uses `feh` rather than `nitrogen`
- clipboard manager uses `copyq` rather than `clipit`
- the categorized app launcher uses `jgmenu` rather than `morc_menu`
- `pamac-tray` and `fix_xcursor` are not assumed to exist on Endeavour/Arch
- `virtualbox-guest-utils` is offered interactively when the installer detects VirtualBox

Locking note:

- `blurlock` is expected to be provided by the `i3exit` package
- `i3exit` is installed from AUR in this bootstrap

## Assumptions

The script assumes:

- a fresh EndeavourOS install
- internet access
- a normal user account with `sudo`
- `pacman` available

Run the script as your normal user, not as root.

## Usage

Clone the repo and run:

```bash
chmod +x install.sh
./install.sh
```

During install, the script will interactively ask about:

- using a safe graphics profile for VMs or weak/unsupported GPU paths
- installing recommended graphics/guest packages based on detected hardware or virtualization

Driver notes:

- VirtualBox guests can install `virtualbox-guest-utils`
- VMware guests can install `open-vm-tools`
- QEMU/KVM guests can install `qemu-guest-agent`
- NVIDIA is detected with kernel-aware suggestions (`nvidia-open`, `nvidia-open-lts`, or manual `nvidia-open-dkms` follow-up depending on the installed kernel)
- AMD is detected explicitly; `mesa` remains the baseline and `vulkan-radeon` is offered as an optional prompt
- Intel is detected explicitly; `mesa` remains the baseline and `vulkan-intel` is offered as an optional prompt

For non-interactive or explicit use, you can still force the safe graphics profile with:

```bash
./install.sh --safe-graphics
```

Safe graphics mode keeps the same general setup but:

- disables picom autostart
- makes Alacritty opaque
- disables blur in Alacritty
- changes the `Super+Ctrl+t` binding into a notice instead of trying to launch picom

If `git` is not installed yet on the fresh machine:

```bash
sudo pacman -S --needed git
git clone <your-repo-url>
cd i3-setup
./install.sh
```

## Re-running

The installer is intended to be re-runnable.

- packages are installed with `--needed`
- replaced user files are backed up first
- service enablement is safe to repeat

## Wallpaper

The default wallpaper is `resources/wallpaper.jpg`.

The installer copies it to:

- `/usr/share/backgrounds/i3-setup-wallpaper.jpg` for LightDM
- `~/Pictures/wallpaper.jpg` for the user session

Replace that file in the repo if you want a different default wallpaper.

## Default Look

The default desktop style shipped by this repo is:

- GTK theme: `Pop-dark`
- icon theme: `Numix-Circle`
- cursor theme: `Adwaita`
- LightDM greeter: `Pop-dark` with `Numix-Circle`
- rofi theme: `arc_dark_transparent_colors`
- terminal theme: dark neon/cyberpunk Alacritty theme with 70% opacity
- shell: `oh-my-zsh` with the `xiong-chiamiov-plus` theme

Other defaults:

- font stack: JetBrains Mono Nerd Font for terminal and i3 bar
- shell plugins: `git`, `zsh-syntax-highlighting`, `zsh-autosuggestions`
- editor default: `nvim`
- browser default: `google-chrome-stable`
- terminal default: `alacritty`

## Default i3 Shortcuts

Main modifier:

- `Super` is the main i3 modifier

Most useful shortcuts:

- `Super+Enter`: open terminal
- `Super+d`: open rofi app launcher
- `Super+F1`: show shortcut popup
- `Super+/`: show shortcut popup
- `Alt+Tab`: rofi window switcher
- `Super+z`: categorized app menu via `jgmenu`
- `Super+F2`: open Google Chrome
- `Super+F3`: open PCManFM
- `Super+Shift+F3`: open PCManFM as root via `pkexec`
- `Super+Shift+w`: alternate Chrome shortcut for VMs/hosts that swallow `Super+F2`
- `Super+Shift+f`: alternate PCManFM shortcut for VMs/hosts that swallow `Super+F3`
- `Super+Ctrl+f`: alternate root PCManFM shortcut for VMs/hosts that swallow `Super+Shift+F3`
- `Print`: open Ksnip screenshot tool
- `Super+Ctrl+x`: xkill

Window management:

- `Super+h/j/k/l`: move focus left/down/up/right
- `Super+Shift+h/j/k/l`: move window left/down/up/right
- `Super+Left/Down/Up/Right`: arrow-key focus movement
- `Super+Shift+Left/Down/Up/Right`: arrow-key window movement
- `Super+q`: close focused window
- `Super+f`: toggle fullscreen
- `Super+Shift+space`: toggle floating
- `Super+space`: switch focus between tiling and floating windows
- `Super+a`: focus parent container
- `Super+Shift+s`: toggle sticky window

Layouts and splits:

- `Super+o`: split horizontally
- `Super+v`: split vertically
- `Super+s`: stacking layout
- `Super+w`: tabbed layout
- `Super+e`: toggle split layout

Workspaces:

- `Super+1..8`: switch workspace
- `Super+Shift+1..8`: move window to workspace and follow it
- `Super+Ctrl+1..8`: move window to workspace without following
- `Super+b`: go back and forth between the last two workspaces
- `Super+Ctrl+Left/Right`: previous or next workspace

Scratchpad and resize:

- `Super+Shift+-`: send window to scratchpad
- `Super+-`: show scratchpad window
- `Super+r`: enter resize mode
- `Super+Shift+g`: enter gaps mode

System/session:

- `Super+9`: lock screen
- `Super+0`: open system mode for lock/logout/suspend/reboot/shutdown
- `Super+Shift+c`: reload i3 config
- `Super+Shift+r`: restart i3
- `Super+Shift+e`: exit i3 session
- `Super+m`: toggle i3 bar visibility

Audio and notifications:

- `Super+Ctrl+m`: open `alsamixer`
- `Super+Shift+d`: restart dunst notifications

Status bar defaults:

- network
- bluetooth
- disk space
- CPU
- memory
- temperature
- sink/source volume
- time
- battery

## Quick VM Test

The fastest safe way to test this is in VirtualBox.

There are two workflows:

1. one-off full install test: create VM, install minimal EndeavourOS, run bootstrap
2. fast repeat test: create one minimal base VM once, snapshot it, then clone from that snapshot for every new bootstrap run

This is the intended iteration loop while tuning the bootstrap:

1. create a fresh VM
2. install minimal EndeavourOS in it
3. run `./install.sh`
4. verify the result
5. if something is wrong, destroy the VM and create a new one

## Fast Template Workflow

This is the recommended workflow once you start iterating heavily.

### 1. Create the Base VM Once

Create a VM dedicated to the base OS install:

```bash
./scripts/create-vbox-test-vm.sh --vm-name i3-setup-base --start
```

Then inside the VM:

1. install minimal EndeavourOS
2. create your normal sudo-enabled user
3. reboot into the installed system
4. do not run `./install.sh` yet
5. power the VM off cleanly

### 2. Snapshot the Minimal Base VM

On the host:

```bash
./scripts/snapshot-vbox-base-vm.sh i3-setup-base minimal-endeavouros
```

You only need to do this again if you want to rebuild the base install.

### 3. Clone a Fresh Test VM from the Snapshot

For each bootstrap test run:

```bash
./scripts/clone-vbox-test-vm.sh --force --start
```

By default this clones:

- base VM: `i3-setup-base`
- snapshot: `minimal-endeavouros`
- test VM: `i3-setup-test`

Inside the cloned VM, run:

```bash
sudo pacman -S --needed git
git clone <your-repo-url>
cd i3-setup
./install.sh
```

### 4. Throw Away the Clone and Repeat

When you want another clean test machine:

```bash
./scripts/reset-vbox-test-vm.sh i3-setup-test
./scripts/clone-vbox-test-vm.sh --force --start
```

This is much faster than reinstalling EndeavourOS every time.

### 1. Download an ISO

If you do not pass an ISO path, the VM helper downloads the latest EndeavourOS ISO automatically.

By default it caches it under:

```bash
~/Downloads/endeavouros/
```

The helper resolves the latest ISO from a mirror index and verifies it with the published SHA-512 checksum.

If the cached ISO is already the latest release and passes checksum verification, it is reused.
If the cached ISO is from an older release or fails checksum verification, the helper removes it and downloads the latest one again.

### 2. Create a VM

Create the VM with:

```bash
./scripts/create-vbox-test-vm.sh
```

Optional custom VM name:

```bash
./scripts/create-vbox-test-vm.sh --vm-name my-i3-test
```

Use a custom ISO cache directory:

```bash
./scripts/create-vbox-test-vm.sh --iso-dir ~/isos/endeavouros
```

If you already downloaded an ISO manually, you can still pass it explicitly:

```bash
./scripts/create-vbox-test-vm.sh /path/to/endeavouros.iso
```

To recreate the same VM name from scratch in one command:

```bash
./scripts/create-vbox-test-vm.sh --force
```

To create and immediately boot it:

```bash
./scripts/create-vbox-test-vm.sh --force --start
```

To start without opening the full VM window:

```bash
./scripts/create-vbox-test-vm.sh --force --headless
```

This creates a VM with:

- 4 GB RAM
- 2 CPUs
- 32 GB disk
- 128 MB video RAM
- VMSVGA with 3D acceleration disabled for stability
- VirtualBox mini-toolbar disabled by default
- NAT networking
- the ISO attached and ready to boot

Then start it:

```bash
VBoxManage startvm i3-setup-test
```

Or start your custom VM name.

### 3. Install the OS in the VM

Boot the ISO and run the EndeavourOS installer.

Use the installer with the smallest/base setup you can choose.

The main rule is:

- do not install an i3 setup from the installer
- do not try to match your final desktop during OS installation
- let this repo build the final desktop after the base system is installed

Inside the installer, do the following:

1. choose EndeavourOS installation as usual
2. choose the minimal/base option when the installer offers package selection
3. create your normal user account
4. make sure that user can use `sudo`
5. finish the install and reboot into the installed system

After reboot, log into the freshly installed system as your normal user.

### 4. Run the Bootstrap Inside the VM

Inside the installed VM:

```bash
sudo pacman -S --needed git
git clone <your-repo-url>
cd i3-setup
./install.sh
```

If the repo is already on a shared folder or mounted path, use that instead.

### 5. Validate

After install, check:

- LightDM starts
- i3 launches successfully
- `zsh` is the default shell
- `nvim`, `code`, `rofi`, `alacritty`, and `google-chrome-stable` are installed
- the wallpaper and theming look correct

Useful commands inside the VM:

```bash
echo $SHELL
command -v nvim code rofi alacritty google-chrome-stable yay
systemctl status lightdm --no-pager
systemctl status NetworkManager --no-pager
```

### 6. Reset and Repeat

When something is wrong and you want another clean machine quickly:

Delete the VM:

```bash
./scripts/reset-vbox-test-vm.sh
```

Recreate it from scratch:

```bash
./scripts/create-vbox-test-vm.sh --force --start
```

That is the fastest clean-slate loop for repeated testing.

If you already created a base VM snapshot, use the template workflow above instead. It is much faster than repeating the full OS install.

## Full Example Session

On the host machine:

```bash
cd /path/to/i3-setup
./scripts/create-vbox-test-vm.sh --force --start
```

Inside the VM after EndeavourOS installation and reboot:

```bash
sudo pacman -S --needed git
git clone <your-repo-url>
cd i3-setup
./install.sh
```

If the result is wrong, back on the host:

```bash
cd /path/to/i3-setup
./scripts/reset-vbox-test-vm.sh
./scripts/create-vbox-test-vm.sh --force --start
```

## Notes

- This repo is intentionally personal in defaults, but should be portable across hardware.
- Hardware-specific values were removed from the shipped config where they would break portability.
- If a package or command is required by the default config, the bootstrap should install it instead of assuming it already exists.
- The VirtualBox helper creates the VM only. The EndeavourOS install itself is still done through the normal graphical installer inside the VM.
- For fast iteration, prefer a base VM snapshot plus linked clones over reinstalling EndeavourOS every time.
