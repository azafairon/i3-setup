# Bootstrap Review Handoff

## Purpose

This document is a work queue for improving the `i3-setup` bootstrap after a
read-only review of commit `234143d`.

It is written for an AI agent or maintainer picking up the repository without
the original review context. Work through the items in priority order, verify
each item independently, and avoid combining unrelated fixes into one change.

Line references describe the reviewed revision and may drift as changes are
made. Search by function or setting name when a line no longer matches.

## Project Intent

The repository is intended to:

- bootstrap a fresh EndeavourOS or Arch-based installation
- install the default i3 desktop, applications, shell, and editor tooling
- preserve replaced user and system files in timestamped backups
- support safe graphics and optional Conky profiles
- be safe to rerun
- provide repeatable VirtualBox test workflows

## Working Rules

- Do not remove or overwrite unrelated user changes.
- Do not run destructive VM commands during development without explicit user approval.
- Preserve normal-user execution; do not change the bootstrap to run as root.
- Avoid `pacman -Sy` without `-u`; partial upgrades are unsupported on Arch.
- Keep normal and noninteractive behavior explicit when package replacement or hardware choices are involved.
- Prefer small changes with focused verification over broad installer rewrites.
- Keep `README.md`, package lists, verification checks, and deployed resources aligned.
- Run static checks after every shell change.
- Test both first install and rerun behavior when changing backup or copy logic.

## Definition Of Done

The review is considered addressed when:

- all P0 items are fixed and tested
- P1 items are fixed or explicitly deferred with rationale
- destructive VM helpers cannot delete unowned or source VMs accidentally
- a stale but supported Arch/EndeavourOS installation is upgraded safely
- safe graphics mode preserves the original user backup
- configured Neovim tools are installed and verified
- current Dunst and i3 configurations validate without obsolete settings
- VM testing identifies the exact repository revision under test
- a documented post-reboot smoke test covers LightDM and i3 startup

## P0: Correctness And Data Safety

### BR-001: Perform A Full Arch Upgrade

Status: [ ] Not started

Problem:

`install_bootstrap_packages` and `install_official_packages` use `pacman -S`
without synchronizing and fully upgrading the system. An older installation ISO
can reference package versions removed from mirrors. Refreshing only package
databases would instead create an unsupported partial upgrade.

Locations:

- `install.sh`, functions `install_bootstrap_packages` and `install_official_packages`
- `README.md`, fresh-install and VM workflows

Implementation direction:

- perform a full `pacman -Syu` before official or AUR package installation
- avoid separate `pacman -Sy` calls
- decide whether bootstrap packages and the full package list can be installed in one upgraded transaction
- document that the bootstrap upgrades the whole system
- make the VM workflow upgrade old linked clones before package installation

Acceptance criteria:

- a fresh clone based on an older package database performs a full upgrade
- no code path refreshes package databases without upgrading installed packages
- rerunning on an up-to-date system remains safe
- README commands match installer behavior

Verification:

```bash
bash -n install.sh
```

Test in a disposable VM created from both a recent base and an intentionally old
snapshot.

### BR-002: Preserve Original Backups In Safe Graphics Mode

Status: [ ] Not started

Problem:

`install_user_configs` copies the normal i3 and Alacritty files first. Safe mode
then installs the safe variants through the same backup helper. The second backup
overwrites the original backup with the just-installed normal template.

Locations:

- `install.sh`, functions `backup_target`, `install_file_with_backup`, `copy_tree_contents`, and `install_user_configs`

Implementation direction:

- choose the normal or safe source before installing each managed target
- install `~/.config/i3/config` and `~/.config/alacritty/alacritty.toml` only once per run
- alternatively, prevent a target's first backup from being overwritten during the same run

Acceptance criteria:

- create distinctive preexisting i3 and Alacritty configs
- run `./install.sh --safe-graphics`
- confirm the backup contains the original files, not repository templates
- confirm the installed files are the safe variants
- confirm rerunning creates a new backup without corrupting the earlier backup

### BR-003: Prevent Destructive VirtualBox Name Collisions

Status: [ ] Not started

Problem:

`clone-vbox-test-vm.sh` permits the base and clone names to be equal. With
`--force`, it can delete the base VM before trying to clone it. Other helpers can
also delete any VM that happens to match a supplied name.

Locations:

- `scripts/clone-vbox-test-vm.sh`, clone validation and `delete_existing_vm`
- `scripts/create-vbox-test-vm.sh`, force recreation
- `scripts/reset-vbox-test-vm.sh`, VM deletion

Implementation direction:

- reject `CLONE_VM_NAME == BASE_VM_NAME`
- tag helper-created VMs with project-specific VirtualBox extradata
- refuse to delete an untagged VM by default
- consider requiring confirmation or a stronger explicit flag for arbitrary names
- prefer graceful ACPI shutdown with a timeout before forced poweroff

Acceptance criteria:

- equal base and clone names fail before any mutation
- `--force` cannot delete an untagged VM
- deleting a tagged test VM still works
- source snapshots and base VMs remain intact after all failure paths

### BR-004: Make NVIDIA Selection Generation-Aware

Status: [ ] Not started

Problem:

GPU detection records only NVIDIA's vendor ID and defaults to `nvidia-open` for
stock kernels. Pre-Turing hardware requires a different strategy, so the current
default can leave older NVIDIA systems without a working graphical session.

Locations:

- `install.sh`, functions `detect_gpu_vendors`, `detect_kernel_packages`, and `configure_nvidia_packages`

Implementation direction:

- inspect PCI display devices and device IDs, not only `/sys/class/drm/card*`
- classify supported Turing-or-newer hardware before selecting `nvidia-open`
- avoid automatic installation when the generation is unknown or unsupported
- handle mixed stock and custom kernels with one consistent fixed-module or DKMS strategy
- document the manual path for legacy NVIDIA hardware

Acceptance criteria:

- supported NVIDIA hardware receives a compatible recommendation
- pre-Turing hardware never defaults to `nvidia-open`
- no-driver or unbound-device states are still detected through PCI enumeration
- mixed-kernel systems do not receive mutually conflicting recommendations

## P1: Configuration And Reproducibility

### BR-005: Load The Login Environment Correctly

Status: [ ] Not started

Problem:

The installer changes the login shell to zsh and installs `.profile`, but zsh
login sessions read `.zprofile`. LightDM runs `/etc/lightdm/Xsession`, which
re-executes zsh as a login shell. GUI applications may therefore miss exports
defined only in `.profile`.

Locations:

- `install.sh`, `install_user_configs` and `change_default_shell`
- `resources/.profile`
- `resources/.zshrc`
- `resources/etc/lightdm/lightdm.conf`, `session-wrapper`

Implementation direction:

- add a managed `.zprofile` that sources `~/.profile`
- review whether `.pam_environment` is still useful on current Arch PAM defaults
- keep interactive-only shell behavior in `.zshrc`
- keep shared environment variables in `.profile`

Acceptance criteria:

- a fresh LightDM login exposes the expected PATH and Qt environment
- a new interactive zsh exposes the same tool paths
- Rustup, Go, npm-local tools, editor, browser, and terminal variables resolve as documented

### BR-006: Install Every Configured Neovim Tool

Status: [ ] Not started

Problem:

Neovim enables `pyright`, NvChad enables `lua_ls`, and Conform requests `stylua`,
but the bootstrap does not install all corresponding executables.

Locations:

- `resources/.config/nvim/lua/configs/lspconfig.lua`
- `resources/.config/nvim/lua/configs/conform.lua`
- `packages`
- `install.sh`, `verify_commands`

Implementation direction:

- install official `pyright`, `lua-language-server`, and `stylua` packages, or remove the corresponding configuration
- add `pyright-langserver`, `lua-language-server`, and `stylua` to postflight checks when retained
- document whether Mason is a UI only or an installer of record

Acceptance criteria:

- Lua, Python, Go, and Rust buffers attach the configured language server on a fresh machine
- Lua and Rust formatting execute successfully
- postflight fails when a configured executable is absent

### BR-007: Modernize Dunst Configuration

Status: [ ] Not started

Problem:

The shipped Dunst configuration contains options removed or ignored by current
Dunst releases. Notification shortcuts and several visual settings do not behave
as configured.

Locations:

- `resources/.config/dunst/dunstrc`
- `resources/.config/i3/config`
- `resources/.config/i3/config-safe`

Known stale entries:

- `bounce_freq`
- `geometry`
- `startup_notification`
- the `[shortcuts]` section
- unquoted `separator_color = #263238`
- `browser = palemoon`, which references an uninstalled browser

Implementation direction:

- use current width, height, origin, and offset settings
- quote color values
- use `xdg-open` or the installed browser
- bind `dunstctl` commands from i3 instead of Dunst's removed shortcut section

Acceptance criteria:

- Dunst starts without unknown or deprecated setting warnings
- notification close, history, and context actions work through i3 bindings
- URL opening uses an installed command

### BR-008: Eliminate Safe i3 Profile Drift

Status: [ ] Not started

Problem:

The normal and safe i3 configs are separate large copies. The safe version has
lost shortcuts and window rules unrelated to graphics, while the README describes
safe mode as a graphics-focused variation.

Locations:

- `resources/.config/i3/config`
- `resources/.config/i3/config-safe`
- `README.md`, safe graphics description

Implementation direction:

- prefer one common i3 config with a small generated or included graphics override
- if separate copies remain, add a semantic comparison test and document intentional differences

Acceptance criteria:

- safe mode changes only documented graphics/Conky behavior
- keyboard shortcuts and non-graphics window rules match the normal profile
- both profiles pass `i3 -C`

### BR-009: Define Managed Directory And Symlink Policy

Status: [ ] Not started

Problem:

`copy_tree_contents` replaces matching files but leaves stale files in managed
directories. It also follows symlinked parent directories. Stale Neovim plugin
modules can change the locked setup, and symlinked dotfile directories can cause
the installer to modify another repository.

Locations:

- `install.sh`, `copy_tree_contents` and `install_file_with_backup`
- `resources/.config/nvim/init.lua`, plugin namespace import

Implementation direction:

- decide which directories are fully managed and which are merged
- for fully managed directories, back up and replace atomically or use a manifest to remove stale managed files
- reject or explicitly handle symlinked managed parent directories
- preserve unrelated files only where merging is intentional

Acceptance criteria:

- stale Neovim plugin modules cannot alter the installed locked configuration
- symlinked managed directories are handled according to documented policy
- reruns remain safe and backups remain recoverable

### BR-010: Make VM Tests Revision-Accurate

Status: [ ] Not started

Problem:

README test workflows clone the remote default branch without proving that it
matches the local revision under development. A VM can therefore test stale code.

Locations:

- `README.md`, all VM clone/bootstrap examples
- VM helper scripts if revision transfer is automated

Implementation direction:

- require an explicit commit or branch in the VM workflow
- print and record `git rev-parse HEAD` and `git status --short`
- document a safe way to transfer the current worktree or patch into the guest
- record the base snapshot date and require periodic rebuilds or full upgrades

Acceptance criteria:

- every VM test result identifies the exact commit and dirty state tested
- a local unpushed change cannot be mistaken for a tested remote revision
- old base snapshots receive a full system upgrade before bootstrap

### BR-011: Strengthen Postflight And Reboot Validation

Status: [ ] Not started

Problem:

Postflight currently proves command presence and service enablement, but not that
the graphical system can start or that deployed configurations are valid.

Locations:

- `install.sh`, `verify_commands` and `postflight_checks`
- `README.md`, VM validation checklist

Implementation direction:

- validate both i3 configs with `i3 -C`
- validate Dunst and status-bar configuration with non-destructive commands
- verify configuration-critical executables, fonts, and language servers
- add an explicit reboot and LightDM/i3 login smoke test to the VM workflow
- distinguish `systemctl is-enabled` from post-reboot `systemctl is-active`

Acceptance criteria:

- malformed i3, Dunst, status, or Neovim tooling fails validation
- VM instructions require reboot and successful LightDM-to-i3 login
- service checks after reboot verify active state where appropriate

### BR-012: Reduce Broad Or Unbacked Replacement

Status: [ ] Not started

Problem:

The installer replaces the full LightDM configuration and overwrites the user
wallpaper outside the backup helper. The wallpaper also assumes `~/Pictures`
instead of the configured XDG pictures directory.

Locations:

- `install.sh`, `install_system_configs` and `install_wallpaper`
- `resources/etc/lightdm/lightdm.conf`
- i3 wallpaper commands

Implementation direction:

- install a minimal LightDM drop-in under `lightdm.conf.d`
- install the wallpaper through the backup helper
- use `xdg-user-dir PICTURES` or a stable managed data path consistently

Acceptance criteria:

- unrelated LightDM administrator settings survive bootstrap
- an existing wallpaper at the managed destination is backed up
- customized XDG user directories work

## P2: Hardening And Maintenance

### BR-013: Handle Existing Package Providers

Status: [ ] Not started

Review conflicts involving:

- `rustup` versus `rust`, `cargo`, and `rustfmt`
- `pipewire-pulse` versus `pulseaudio`
- NVIDIA fixed-kernel, open, proprietary, and DKMS providers
- stable versus Git Numix icon packages

Do not rely on `--noconfirm` to make replacement decisions. Detect suitable
existing providers and ask before intentional replacement.

### BR-014: Harden Privileged Command Resolution

Status: [ ] Not started

The installer prepends user-writable directories to PATH before invoking
privileged commands. Use a trusted PATH or absolute command paths during package,
system-file, service, and shell-changing phases. Add user tool directories only
for user-level setup and verification.

### BR-015: Review AUR Trust And Pinning

Status: [ ] Not started

`yay` and AUR PKGBUILDs are fetched from moving repositories and executed with
`--noconfirm`. Decide whether to pin reviewed AUR revisions, require manual review,
or explicitly accept this trust model in documentation.

### BR-016: Improve ISO And VM Resource Safety

Status: [ ] Not started

Potential improvements:

- verify EndeavourOS detached signatures with a documented signing-key fingerprint
- download to a temporary file, verify, then atomically replace the cache entry
- prune only helper-managed ISO files
- detach installation media before taking the reusable base snapshot
- require the base VM state to be exactly `poweroff`, not merely absent from `runningvms`
- check and document the supported VirtualBox version
- add cleanup traps for partially created VMs and media

### BR-017: Improve Installer Recovery

Status: [ ] Not started

Potential improvements:

- prevent same-second or concurrent backup directory collisions
- add cleanup traps for temporary AUR build directories
- decide how long-running installs renew or regroup sudo authentication
- validate the real invoking account instead of trusting `$USER`
- verify existing Oh My Zsh and Powerlevel10k directories are complete and usable
- avoid chmodding unrelated files already present in `~/.local/bin`

### BR-018: Complete Minor Dependency And UX Cleanup

Status: [ ] Not started

Review these lower-priority inconsistencies:

- install or replace configured Noto and URW fonts
- remove or guard Bash aliases for uninstalled `nano`, `unrar`, and `7z`
- decide whether npm-local directories should exist when Node/npm are not installed
- handle the battery block on desktop systems without a battery
- fix workspace formatting in `resources/.local/bin/i3-keyhints`
- decide whether NvChad plugins should be synchronized during bootstrap or on first launch

## Suggested Work Order

1. BR-001 full system upgrade
2. BR-002 safe backup preservation
3. BR-003 VM deletion safety
4. BR-004 NVIDIA policy and detection
5. BR-005 login environment
6. BR-006 missing Neovim tools
7. BR-007 Dunst modernization
8. BR-008 safe profile consolidation
9. BR-009 managed directory policy
10. BR-010 revision-accurate VM testing
11. BR-011 postflight and reboot validation
12. BR-012 broad replacement cleanup
13. P2 hardening items

BR-002 and BR-009 should be designed together if backup/copy helpers are being
refactored. BR-001 should be completed before relying on the VM workflow to test
package installation. BR-003 should be completed before running destructive VM
helper tests.

## Verification Checklist

Run after shell changes:

```bash
bash -n install.sh scripts/*.sh
git diff --check
```

Run after i3 changes:

```bash
i3 -C -c resources/.config/i3/config
i3 -C -c resources/.config/i3/config-safe
```

Run after Rust or Neovim changes:

```bash
command -v nvim gopls pyright-langserver lua-language-server rust-analyzer rustfmt stylua
rustup show active-toolchain
rustup component list --installed
```

Required disposable-VM scenarios:

- current EndeavourOS base, normal profile
- current EndeavourOS base, safe graphics profile
- rerun normal profile over an existing installation
- rerun safe profile over customized i3 and Alacritty configs
- old base snapshot requiring a full upgrade
- existing PulseAudio provider
- existing distro Rust provider
- Intel GPU
- AMD GPU
- supported NVIDIA GPU
- legacy or unknown NVIDIA GPU
- VirtualBox guest
- QEMU/KVM guest when available

Post-reboot smoke checks:

```bash
getent passwd "$USER" | cut -d: -f7
systemctl is-active lightdm NetworkManager
systemctl --failed
i3 -C -c "$HOME/.config/i3/config"
command -v nvim rofi alacritty google-chrome-stable rust-analyzer gopls
```

Also verify manually:

- LightDM reaches the greeter
- login opens i3
- i3status renders without critical blocks
- notifications and Dunst controls work
- audio, network, Bluetooth, locking, logout, suspend, and shutdown work
- Neovim attaches Lua, Python, Go, and Rust language servers
- original backups are recoverable

## Open Decisions Requiring Maintainer Input

Do not guess these policies during implementation:

- Should the installer always perform a full system upgrade automatically?
- Should managed config directories be merged, manifest-managed, or replaced completely?
- Should existing package providers be retained or replaced with repository defaults?
- Which NVIDIA generations and driver families should the bootstrap support automatically?
- Should AUR revisions be pinned, manually reviewed, or accepted as moving dependencies?
- Should NvChad plugins be installed during bootstrap or on first editor launch?
- Should the normal and safe i3 profiles become one generated configuration?

## Existing Strengths To Preserve

- scripts consistently use `set -euo pipefail`
- the installer refuses root execution
- AUR builds run as the normal user
- arrays and quoting are generally sound
- most replaced files are backed up
- Oh My Zsh and Powerlevel10k are pinned on fresh installs
- official and AUR package lists are separated
- both current i3 profiles pass `i3 -C`
- monitor handling avoids hardcoded output names
- the Rustup, Treesitter, formatter, and Rust LSP setup is aligned
- linked-clone VM testing provides a useful foundation for repeatable tests
- the README documents the intended installation and testing workflow extensively

## Review Limitations

- review was static and read-only
- ShellCheck was not installed on the review host
- VirtualBox was not installed on the review host
- no full bootstrap or post-reboot graphical test was performed
- physical GPU detection paths were not exercised
- AUR PKGBUILDs were not audited in depth
