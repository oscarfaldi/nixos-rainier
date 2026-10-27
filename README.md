# nixos-rainier

*I use NixOS btw.*

My personal NixOS configuration, managed declaratively and stored as a single source of truth.

This repository contains my complete desktop setup: window manager, applications, development environment, personal scripts, dotfiles, wallpapers, and system configuration — all managed through NixOS and Home Manager.

## The Stack

| Component | Role |
|-----------|------|
| [NixOS](https://nixos.org) | Base operating system |
| [Home Manager](https://nix-community.github.io/home-manager/) | User-level configuration |
| [Niri](https://github.com/YaLTeR/niri) | Wayland compositor (scrollable tiling) |
| [Quickshell](https://quickshell.org) | Bar, panels, popups, notifications, lock screen |
| [Ghostty](https://ghostty.org) | Terminal emulator |
| [Thunar](https://docs.xfce.org/xfce/thunar/start) | File manager |

Unlike a traditional Linux setup where configuration is scattered across `/etc`, `~/.config`, and application-specific directories, this repository acts as the single source of truth for nearly everything. Most configuration files, scripts, themes, wallpapers, and application settings live inside `~/System` and are managed declaratively through NixOS and Home Manager.

## Hardware

This configuration is primarily built and tested on:

- AMD Ryzen 5 5600
- NVIDIA RTX 3060 Ti
- 32 GB DDR4 RAM

NVIDIA-specific configuration is included.

## Philosophy

> `~/System` is the single source of truth.

Instead of scattering configuration across `/etc`, `~/.config`, and application-specific directories, almost everything lives inside this repository and is managed through NixOS and Home Manager.

The goal is reproducibility: a fresh machine should become my daily workstation with minimal manual setup.

### Editing Configuration

Never edit generated files inside `~/.config` directly. Home Manager creates symlinks from `~/.config` back into the repository, so changes made there will be overwritten on the next rebuild.

Edit the source files inside:

```text
~/System/.config
```

### Quick Access

The fastest workflow is through the **launcher** (`Mod+D`). From there, jump directly into **Yazi** inside the repository and edit files from there.

For GUI editing, **Mousepad** can open files inside `~/System` without running into permission issues, since the repository is owned by the user rather than root.

### Golden Rules

- Edit `~/System`, not generated locations.
- Rebuild instead of manually fixing configuration.
- Keep configuration deterministic.
- If something requires an imperative step, document why.

## Installation

### 1. Install NixOS

Install a fresh copy of NixOS **without a desktop environment**.

This repository already provides the complete desktop environment, window manager, applications, and user configuration, so KDE, GNOME, XFCE, or any other desktop environment is unnecessary.

After installation completes, reboot into the newly installed system.

### 2. Install Git and clone the repository

Log in from the console and temporarily install Git:

```bash
nix-shell -p git
```

Clone the repository:

```bash
git clone git@github.com:oscarfaldi/nixos-rainier.git ~/System
```

The repository is intentionally cloned into `~/System`, which serves as the central location for the entire machine configuration. Dotfiles, scripts, themes, wallpapers, and Home Manager-managed configuration live here instead of being edited directly inside `~/.config`. Home Manager creates symlinks where necessary, making the repository the primary location for configuration changes.

### 3. Prepare the installer

Move into the repository and make the installation script executable:

```bash
cd ~/System
chmod +x install
```

### 4. Run the installer

```bash
./install
```

The installation script performs the initial bootstrap process:

- Imports the generated hardware configuration into the repository
- Removes the default `/etc/nixos` configuration to avoid configuration drift
- Builds from the pinned revisions in `flake.lock` (identical state on every reinstall)
- Installs and configures Home Manager
- Configures SMB credentials for network shares
- Restores selected application settings
- Performs the initial system build
- Reboots the machine automatically

After installation, the repository becomes the primary source of truth for the system.

To move the system to a newer nixpkgs later, run `upgrade` from the installed system: it updates
`flake.lock`, rebuilds, and prints the package diff. `install` never updates inputs on purpose.

### 5. Rebuild after reboot

Once the system comes back online:

```bash
rebuild
```

or

```bash
sudo nixos-rebuild switch
```

The machine should now be fully configured.

## Repository Structure

The repository is organized by responsibility instead of putting everything into a single `configuration.nix`. Each directory has a specific purpose.

| Directory | Purpose |
|-----------|---------|
| `.config/` | Dotfiles and application configuration |
| `.local/share/applications/` | Custom desktop launchers |
| `home/` | Home Manager configuration |
| `modules/` | NixOS modules |
| `scripts/` | Custom automation scripts |

### `.config`

This is where most user-facing configuration lives — the equivalent of a traditional `~/.config`, except the real source files live inside the repository and are linked by Home Manager.

It contains configuration for:

- Niri
- Quickshell
- Ghostty
- MPV
- Yazi
- Zsh
- Starship
- and other applications

Most ricing, UI customization, and application behavior is defined here.

#### `assets`

Static assets that are not configuration: the SVG icons used by the launcher and the web-app entries,
plus the two notification sounds. Wallpapers are not here - each theme owns its own under
`themes/<name>/backgrounds/`.

### `.local/share/applications`

This directory contains custom desktop launchers (`.desktop` files) that override default application launchers.

Instead of accepting default launch behavior, I customize them to match my workflow:

- Hiding launchers I never use
- Replacing default launch behavior
- Creating workflow-specific shortcuts

A good example is the [Counter-Strike 2 launcher](#counter-strike-2), covered under Scripts.

### `home`

This directory contains Home Manager configuration. Home Manager declaratively manages user-level configuration that would normally live inside the home directory.

One important file is `files.nix`. Instead of copying configuration files manually, it creates symlinks back into the repository:

- `~/.config/niri`, `~/.config/ghostty/shaders`, `~/.config/zsh`
- `~/System/assets`, `~/.config/yazi`, `~/.config/mpv`, `~/.config/qimgv`
- `~/.config/Thunar`, `~/.config/pdfarranger`, `~/.config/xdg-desktop-portal`
- `~/.local/share/applications/` (launcher entries, one symlink per file)

Applications that write their own settings at runtime (GTK, btop, the theme state directory) are
deliberately not linked here: one writer per file, or the build and the app fight over it.

All point back to their equivalents inside `~/System`. This keeps configuration editable from one place while still allowing applications to use their expected locations.

### `modules`

`modules` contains the actual NixOS configuration. Rather than one massive `configuration.nix`, the system is split into smaller modules grouped by purpose:

| Module | Purpose |
|--------|---------|
| `audio.nix` | PipeWire, WirePlumber and the audio services |
| `appearance.nix` | Fonts, cursors, and styling defaults |
| `content-creation.nix` | Editors and media tools used for content work |
| `edge-policy.nix` | Declarative Microsoft Edge policies |
| `games.nix` | Steam and gaming configuration |
| `greeter.nix` | Login greeter |
| `keyboard.nix` | Keyboard layout and keyd remaps |
| `lock.nix` | PAM service for the Quickshell lock screen |
| `localsend.nix` | LocalSend file transfer between the phone and the desktop, with its LAN ports |
| `network.nix` | NetworkManager, local DNS, and network automation |
| `nvidia.nix` | NVIDIA driver and kernel module configuration |
| `packages.nix` | System packages |
| `polkit.nix` | Polkit rules for the power actions |
| `pwa-edge.nix` / `pwa-firefox.nix` | Web-app shortcuts |
| `smb-kernel-mount.nix` | NAS shares, mounted on access |
| `syncthing.nix` | Syncthing with a declarative device set |
| `tmpfs.nix` | tmpfs mounts (`/tmp` in RAM) |

This makes individual parts of the system easier to maintain and reuse.

#### `modules/network.nix`

This module keeps the entire network configuration declarative. Instead of manually creating NetworkManager profiles through a GUI, every connection is defined in Nix.

**Network layout:**

| Network | Purpose |
|---------|---------|
| `10.10.10.x` | Internet and Unraid management |
| `10.10.20.x` | Intel X540-T2 Port 1 (10G) |
| `10.10.21.x` | Intel X540-T2 Port 2 (10G) |

The standard LAN handles internet access and management, while the two dedicated 10 Gb interfaces are reserved for high-speed NAS traffic.

**Local domains:**

Instead of remembering IP addresses, services are accessed through hostname shortcuts:

- `files.local`
- `music.local`
- `movies.local`
- `grafana.local`
- `ai.local`
- `office.local`

These all resolve to the Unraid server at `10.10.10.10`.

**Deterministic NetworkManager:**

NetworkManager has a habit of accumulating old or temporary connection profiles over time. This module includes a cleanup service that automatically removes unmanaged profiles while preserving only the expected connections. The result:

- Predictable network configuration
- No duplicate ethernet profiles
- Less GUI clutter
- Reproducible networking after rebuilds

## Scripts

One of the best parts of Linux is turning repetitive tasks into permanent workflow improvements. Instead of installing separate applications for every small task, most common actions are standardized into scripts that integrate directly with Thunar, the launcher, or the terminal.

> Build it once, use it everywhere.

The scripts are grouped by responsibility rather than by programming language:

| Directory | Purpose |
|-----------|---------|
| `actions/` | File operations and Thunar workflows |
| `apps/` | Application launch wrappers |
| `launchers/` | Launcher menu shortcuts |
| `systems/` | System maintenance |
| `themes/` | Wallpaper and theme automation |

### `scripts/actions`

Scripts designed around file management. Most of them are exposed through **Thunar Custom Actions**, turning right-click actions into reusable workflows — the file manager becomes the interface.

#### Inspect File

`inspect-file` is a universal metadata inspector. It combines multiple tools behind a single interface:

- ExifTool
- FFprobe
- PDFInfo
- XDG MIME detection

Depending on the selected file type, it automatically displays relevant information:

- Camera metadata
- GPS coordinates
- Video codecs
- HDR format
- Audio quality
- PDF information
- Office document metadata
- File permissions

Instead of opening multiple utilities, everything appears inside a single window.

#### MKV Compress

This is my primary long-term video compression workflow. Originally I relied on Unmanic running on my Unraid NAS, but I eventually preferred running the entire workflow directly on my desktop.

Features:

- NVIDIA NVENC HEVC encoding
- Constant QP quality
- Audio stream copy
- Folder support
- Multiple file support
- Progress window inside Ghostty
- Desktop notifications
- Preserves original timestamps

Output:

```text
filename-encoded.mkv
```

The script is intentionally designed for archival rather than streaming optimization.

#### Video Rotation

Simple FFmpeg wrappers that rotate videos without opening an editor:

- Landscape → Portrait
- Portrait → Landscape

The output is generated directly from Thunar.

#### Image Conversion

Image conversion is standardized into dedicated scripts. Supported output formats:

- AVIF
- JPEG
- PNG
- PDF

Depending on the target format, the backend changes automatically:

- `avifenc` for AVIF
- ImageMagick for image formats
- Pandoc where document conversion is appropriate

Batch conversion is supported, making it useful for large collections.

### `scripts/apps`

These scripts wrap existing applications into more convenient entry points. The applications themselves stay unchanged — the launch behavior becomes smarter.

#### Counter-Strike 2

The custom CS2 launcher automatically:

- Enables NVibrant
- Increases digital vibrance
- Launches the game under X11
- Restores the previous state after exiting

This solves Wayland compatibility issues while keeping the workflow down to a single click.

#### Ghostty Wrappers

Some terminal applications automatically open inside Ghostty:

- `btop`
- `yazi`

This keeps terminal tools feeling like standalone applications while preserving a consistent terminal environment.

### `scripts/launchers`

These scripts exist primarily for the launcher. Instead of remembering terminal commands, frequently used actions become searchable launcher entries:

- Opening configuration folders
- Jumping into `~/System`
- Opening `modules`
- Launching Yazi in specific locations
- Rebooting
- Shutting down

The goal is reducing navigation friction rather than replacing the terminal.

### `scripts/systems`

These scripts replace long administrative commands with predictable shortcuts — commands I run regularly enough that I no longer want to remember the full syntax.

#### `rebuild`

The command I use most. Instead of:

```bash
sudo nixos-rebuild switch -I nixos-config=~/System/configuration.nix
```

I simply run:

```bash
rebuild
```

The script always rebuilds using the repository as the active configuration source and prints useful system information afterward.

#### `upgrade`

Updates Nix channels, packages, and system generation, then rebuilds the system.

#### `clean`

Every rebuild creates a new system generation. `clean` removes old generations and frees storage while keeping the system organized.

#### `smart-report`

Generates a complete SMART health report for every installed HDD and SSD. Useful for periodically checking NAS and desktop drive health without manually querying each disk.

#### `nas-recover`

Recovers the CIFS shares when a dead SMB session freezes the desktop. A hung mount puts every process
that touches it into uninterruptible sleep, so the file manager cannot be killed and reopening it
hangs again - the session itself has to be destroyed. The script kills what holds the mount, forces
the mount away, remounts through systemd, and verifies the share answers. `nas-recover --check` runs
the same diagnosis without changing anything.

`--check` also prints the active mount options and the recent CIFS kernel messages, which is the
evidence that tells "the mount on this machine is stale" apart from "the server stopped answering".

Both, plus the archive action, are reachable from the **NAS** entry in the launcher.

### `scripts/themes`

The theme system. One palette drives everything that can change at runtime, and switching never needs
a rebuild - the colours live in `~/.local/state/theme/`, not in the Nix store, so the same
`theme-apply <name>` call works on a fresh install and on a running desktop.

```text
themes/<name>/colors.toml        the palette (Omarchy format)
themes/<name>/backgrounds/       that theme's wallpapers
theme-apply <name>               render every runtime config, set the wallpaper, reload the apps
theme-list / theme-current       read-only helpers
themes-menu                      the rows the launcher shows (Mod+D -> "theme")
```

What follows the palette: the Quickshell shell (bar, popups, dialogs), Ghostty, btop, GTK
(`Adwaita-dark` recoloured through `@define-color`), qs-lock, Obsidian (CSS snippet) and the
wallpaper. Starship keeps its own prompt palette on purpose.

Adding a theme is dropping a folder with `colors.toml` and `backgrounds/`; official ones live in the
repo and reach `/etc/qs-palettes/`, personal tweaks go in `~/.local/share/qs-palettes-user/` where
they shadow an official theme of the same name - no rebuild either way. Wallpapers work the same:
anything added to `<theme>/backgrounds/` (official) or
`~/.local/share/qs-palettes-user/<theme>/backgrounds/` is picked up automatically.

Choosing the theme that is already active rotates to its next wallpaper, so one menu entry does both
jobs. The wallpaper itself is drawn by the shell (`main/wallpaper/Wallpaper.qml`, one background-layer
surface per output reading `~/.local/state/theme/wallpaper`), not by a wallpaper daemon: there is no
second process to start, no socket to reconnect and no output that can appear too late. `theme-apply`
and `wallpaper-next` only write that path. `wallpaper-session` still runs at login, but only to seed an
empty state directory on a fresh install.

## Decisions

This section documents decisions that future me is most likely to forget.

### Why Niri instead of Hyprland?

Hyprland has the larger ecosystem.

Niri changed how I use my desktop. Instead of treating one workspace as a crowded desktop, each task naturally moves into its own workspace. That workflow fits my habits better than stacking multiple windows inside one space.

### Why `~/System` instead of `/etc/nixos`?

Two reasons.

First, `/etc/nixos` constantly requires elevated permissions.

Second, I wanted one repository containing everything:

- Nix configuration
- Dotfiles
- Wallpapers
- Scripts
- Assets

One repository. One source of truth.

### Why Home Manager symlinks?

Mostly because it's the native Nix approach. On a traditional Linux distribution, I'd probably solve the same problem with GNU Stow.

### Why NixOS unstable?

"Unstable" in NixOS doesn't mean unreliable. I prefer newer packages, better hardware support, and a faster update cadence. In practice, it's been stable enough for my daily desktop.

## Hostnames

My devices are named after landscapes of the Pacific Northwest. The region represents many things I admire: wilderness, mountains, forests, craftsmanship, solitude, exploration, and a slower side of Americana that exists beyond the major cities.

**Arizona** is not a device — it is the identity behind the system.

**Cascade** serves as the foundation. Named after the Cascade Range, it represents the underlying backbone that everything else depends on. As the NAS, it acts as the source of truth for data, services, media, backups, and infrastructure.

**Rainier** is the primary workstation. Inspired by Mount Rainier, the most prominent peak in the region, it serves as the main machine for work, experimentation, and everyday computing.

**Baker** is the mobile companion. Named after Mount Baker, it represents exploration, flexibility, and the ability to remain connected while operating beyond the desk.

The names are less about geography and more about the roles these machines play within a shared landscape.
