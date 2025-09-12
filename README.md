 ░▒▓██████▓▒░░▒▓████████▓▒░▒▓█▓▒░      ░▒▓██████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░  
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░      ░▒▓██████▓▒░ ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░ 
░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
 ░▒▓██████▓▒░░▒▓████████▓▒░▒▓████████▓▒░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
# Celona
A customizable, modern status bar and desktop UI built with Quickshell and Qt/QML. Celona focuses on practical ergonomics, clean visuals, and tight integration with common Wayland environments such as Niri and Hyprland.

Celona ships a collection of self-contained bar modules (blocks), a setup UI, and helper scripts to streamline daily workflows.

## Demo
![screenshot](https://github.com/myinqi/Celona/demo/screenshot.png)

## Highlights

- Minimal, readable design with keyboard-first workflows
- Dynamic workspaces and window awareness (Niri, Hyprland)
- Theme system with Matugen integration (auto-palette from wallpaper)
- Light/Dark mode switching that also syncs external apps
- Sensible defaults with a single JSON configuration file
- Extensible QML-based modules and clean code structure

## Project Structure

Key paths in this repository:

- `shell.qml` – entry point for Quickshell
- `bar/` – the status bar and its modules ("blocks")
  - `blocks/` – individual modules (Clipboard, InfoKeybinds, WindowSelector, etc.)
  - `blocks/setup/` – setup pages (Theme, Wallpapers, etc.)
- `scripts/` – helper scripts used by modules and setup pages
- `config.json` – primary configuration file for Celona
- `colors.css` – Matugen-generated palette (auto-generated)
- `Globals.qml` – project-wide state, theme handling, and integrations

## Requirements

- Arch based Linux I tested it on CachyOS
- Fish shell
- Quickshell (Wayland widget engine)
- Qt/QML (via Quickshell runtime)
- For integrations and scripts:
  - `matugen` (theme palette generator)
  - `jq` (JSON tooling)
  - `ffmpeg` (optional; first-frame extraction from animated wallpapers)
  - `swww` or your configured wallpaper tool (optional)
  - `wl-clipboard` (`wl-copy`/`wl-paste`) and `cliphist` for the Clipboard module
  - `ghostty` (optional; theme sync)
  - `fuzzel` (optional; theme sync)
  - `swaync` (optional; theme sync)
  - `cava` (optional; theme sync)
  - `nwg-look` (optional; theme sync)
  - `kvantum` (optional; theme sync)
  - `mpvpaper` (optional; animated wallpapers)
  - `hyprgreetr`, `hyprlock` (optional; theme sync)
  - `niri` or `hyprland` 

Most optional dependencies are used only if present and configured.

## Installation

1) Niri (recommended): follow the detailed steps in the installation.txt file (this file describes the installation on a fresh CachyOS system)

2) Hyprland: its also possible to use Celona with a existing Hyprland installation but only if you use MyLinux4Work Dotfiles (future plan is to update Celona to a standalone version for hyprland)
-   for this way install quickshell, cd into ~/.config/quickshell and clone this repository
-   replace the waybar spawn in your hyprland config with "quickshell --config ~/.config/quickshell/Celona" and toogle off waybar in the ml4w settings app.

## Configuration

The primary configuration file is `config.json` in the repository root. It holds paths and feature flags that modules and setup pages read at runtime. Notable keys include:

- `wallpaperStaticPath` – path to a static wallpaper image
- `wallpaperAnimatedPath` – path to an animated wallpaper (video)
- `keybindsPath` – path to keybinds file; supports Hyprland `.conf` or Niri `.kdl`
- Various toggles for showing/hiding modules

When theme settings are changed via the setup UI (Gear-Icon in the left corner of the bar), the updated values are persisted to `config.json` by `Globals.saveTheme()`.

## Theming and Light/Dark Toggle

Celona integrates with Matugen to derive a color palette from your wallpaper.

- The Theme page (Setup) exposes a "Use Matugen colors" toggle and a "Theme Mode" button.
- The button runs `scripts/matugen-toggle.sh`, which:
  - Chooses a source image (static wallpaper or first frame from animated video)
  - Generates `colors.css` for the selected mode (`light`/`dark`)
  - Updates the system GTK color scheme via `gsettings`
  - Optionally updates the Qt (Kvantum) theme via `scripts/qt-kvantum-mode.sh` if present
  - Persists the selected mode under `~/.config/quickshell/Celona/matugen_mode`
- After generation, Celona loads and applies the palette, updates bar colors, and synchronizes optional integrations:
  - Niri active/inactive colors (`~/.config/niri/config.kdl`)
  - Ghostty (`~/.config/ghostty/themes/matugen_colors.conf` + live OSC script)
  - Fuzzel (`~/.config/fuzzel/themes/matugen_colors.ini`)
  - Hyprgreetr, Hyprlock, Cava, SwayNC (respective config files)

### Kvantum (Qt) Theme Sync

To sync Qt apps using Kvantum on Light/Dark toggle, ensure this helper exists and is executable:

- `scripts/qt-kvantum-mode.sh`

Default themes can be overridden via environment variables when launching Quickshell:

```sh
LIGHT_THEME=KvGlassWhite DARK_THEME=KvGlass quickshell --config ~/.config/quickshell/Celona
```

Celona will call the helper with `light` or `dark`.

## Modules

The following modules live under `bar/blocks/`. Unless noted otherwise, each item is a single QML file with its own inline popup and relies on `Globals.qml` theme colors. All popups cooperate via a global popup context so only one is visible at a time.

- `ActiveWorkspace.qml` — compact indicator for the currently focused workspace.
- `Barvisualizer.qml` — simple bar visualizer that reacts to theme changes (`Globals.themeEpoch`).
- `Battery.qml` — battery status and popup details.
- `Bluetooth.qml` — Bluetooth indicator and quick actions (if supported on the system).
- `CPU.qml` — CPU usage indicator.
- `Clipboard.qml` — clipboard history via `cliphist` and `wl-clipboard`; left‑click shows entries, right‑click offers management actions.
- `Date.qml` — date display.
- `Datetime.qml` — combined date and time display (alternative to using `Date.qml` + `Time.qml`).
- `GPU.qml` — GPU usage indicator.
- `InfoKeybinds.qml` — keybinds cheatsheet.
  - Hyprland: parses `.conf`.
  - Niri: parses `config.kdl` (`binds { ... }` and `binding { ... }`). Set `keybindsPath` in `config.json`.
- `Memory.qml` — memory usage indicator.
- `Network.qml` — network status indicator.
- `Notifications.qml` — unread notifications indicator (if supported in your environment).
- `Power.qml` — power menu actions (shutdown, reboot, etc.).
- `PowerProfiles.qml` — power profiles toggle/indicator, if available.
- `Setup.qml` — entry to the setup dialog (gear icon) to manage theme and behavior.
- `SetupDialog.qml` — wrapper dialog for setup pages.
- `Sound.qml` — volume and sink/source controls with popup.
- `SystemTray.qml` — system tray area for compatible tray icons.
- `Time.qml` — time display.
- `Updates.qml` — system/package update indicator.
- `Weather.qml` — weather info (optional; requires network access and configuration).
- `Welcome.qml` — welcome message and hints area (can be hidden via settings).
- `WindowSelector.qml` — lists open windows; supports Niri (`niri msg -j windows/workspaces`) and Hyprland.
- `WindowTitle.qml` — shows the active window title.
- `Workspaces.qml` — workspace strip with active/inactive visuals.

### Setup pages (bar/blocks/setup/)

- `DockPage.qml` — dock configuration (position, size, behavior, colors).
- `LayoutPage.qml` — bar layout, positions, margins, and visibility.
- `ModulesPage.qml` — toggle available modules on/off and ordering.
- `SystemPage.qml` — system integration settings.
- `ThemePage.qml` — Matugen, theme colors, and Light/Dark mode switch.
- `WallpapersPage.qml` — static/animated wallpaper configuration and tools.

Modules register with a global popup context to ensure only one popup is visible at a time.

## Usage Tips

- Hover and click bar modules to open their popups.
- Use the Setup gear (if enabled) to adjust colors and features.
- For the Keybinds module, set `keybindsPath` to your Hyprland or Niri configuration file. For Niri, pointing to `~/.config/niri/config.kdl` enables direct parsing from the `binds` block.

## Development

- Code style: QML + small helper scripts (bash). Keep modules self-contained.
- Popups should respect `Globals.popupContext` to maintain mutual exclusivity.
- Prefer non-destructive file updates for external integrations and validate file availability before writing.
- Use `console.log` with clear prefixes per module to aid debugging.

### Running locally

```sh
quickshell --config ~/.config/quickshell/Celona
```

### Logs

Quickshell prints log locations on startup. You can tail them as needed:

```sh
tail -f /run/user/$(id -u)/quickshell/by-id/*/log.qslog
```

## Troubleshooting

- If Matugen changes are not reflected, ensure `colors.css` exists and that `Globals.useMatugenColors` is enabled. Use the matugen config provided in the .config folder of this repository.
- If the Light/Dark toggle fails, verify the wallpaper paths and that `matugen`, `jq`, and optionally `ffmpeg` are installed.
- If Qt apps do not reflect the theme, confirm `scripts/qt-kvantum-mode.sh` is executable and you are using Kvantum.
- For Niri integrations, verify that `~/.config/niri/config.kdl` is readable and that `niri msg` commands are available.

## License

This project is released under the MIT License. 