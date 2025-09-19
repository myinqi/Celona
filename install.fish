#!/usr/bin/env fish
# Celona automated installer for CachyOS systems (Fish shell)
# Safe-ish defaults, idempotent where possible, with interactive prompts.
#
# Notes:
# - It assumes you’re on CachyOS with pacman and systemd.

status is-interactive; and set -l IS_INTERACTIVE 1; or set -l IS_INTERACTIVE 0

function die
    set_color red
    echo "ERROR: $argv"
    set_color normal
    exit 1
end

function warn
    set_color yellow
    echo "WARN: $argv"
    set_color normal
end

function info
    set_color cyan
    echo "==> $argv"
    set_color normal
end

set -l DO_BTRFS 0

# Confirm helper
function confirm --argument-names prompt
    read -l -P "$prompt [y/N]: " resp
    switch (string lower -- $resp)
        case y yes
            return 0
        case '*'
            return 1
    end
end

# Require prerequisites
command -q sudo; or die "sudo is required"
command -q pacman; or die "pacman is required (Arch/CachyOS)"
command -q rsync; or begin
    info "Installing rsync (required)"
    sudo pacman -S --noconfirm --needed rsync; or die "Failed to install rsync"
end

set -l CELONA_DIR ~/.config/quickshell/Celona
set -l QSHELL_DIR ~/.config/quickshell

# ASCII banner (from scriptinput)
function celona_banner
    echo "░▒▓██████▓▒░░▒▓████████▓▒░▒▓█▓▒░      ░▒▓██████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░  "
    echo "░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ "
    echo "░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ "
    echo "░▒▓█▓▒░      ░▒▓██████▓▒░ ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░ "
    echo "░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ "
    echo "░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ "
    echo " ░▒▓██████▓▒░░▒▓████████▓▒░▒▓████████▓▒░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ "
end

clear
celona_banner

# Verify Celona repo exists
if not test -d $CELONA_DIR
    die "Celona repo not found at $CELONA_DIR. Please clone it there and rerun the installer."
end

# Ask whether system uses Btrfs (to run snapper steps)
if confirm "Is your system using Btrfs (apply Snapper steps)?"
    set DO_BTRFS 1
else
    set DO_BTRFS 0
end


# Ask whether to install Hyprland alongside Niri
set -l DO_HYPR 0
if confirm "Also install Hyprland alongside Niri?"
    set DO_HYPR 1
end


# Optional Btrfs/Snapper flow
if test $DO_BTRFS -eq 1
    info "Btrfs/snapper setup"
    if not command -q snapper
        info "Installing snapper"
        sudo pacman -S --noconfirm --needed snapper; or die "Failed to install snapper"
    end
    sudo snapper -c home create-config /home; or warn "snapper home config may already exist"
    sudo snapper list-configs; or warn "snapper list-configs failed"
    sudo snapper -c root set-config ALLOW_USERS="$USER" SYNC_ACL=yes; or warn "set-config root failed"
    sudo snapper -c home set-config ALLOW_USERS="$USER" SYNC_ACL=yes; or warn "set-config home failed"
    if test -w /etc/updatedb.conf
        # Append .snapshots to PRUNENAMES if missing
        set -l tmp (mktemp)
        sudo cp /etc/updatedb.conf $tmp; or warn "cannot copy updatedb.conf"
        if grep -q ".snapshots" $tmp
            info ".snapshots already present in PRUNENAMES"
        else
            info "Adding .snapshots to PRUNENAMES"
            set -l sedexpr 's/PRUNENAMES = \"/PRUNENAMES = \".snapshots /'
            cat $tmp | sed -E $sedexpr | sed -E 's/\.snapshots \.snapshots/.snapshots/' | string collect | sudo tee /etc/updatedb.conf >/dev/null
        end
        rm -f $tmp
    else
        warn "/etc/updatedb.conf not writable or missing"
    end
    info "Disabling snapper timeline/cleanup timers during install"
    sudo systemctl disable --now snapper-timeline.timer snapper-cleanup.timer; or warn "could not disable snapper timers"
    snapper -c root create -t pre -c number -d 'pre Celona installation'; or warn "root pre snapshot failed"
    snapper -c home create -t pre -c number -d 'pre Celona installation'; or warn "home pre snapshot failed"
end

# Ensure GNOME portal is present to avoid provider selection when installing Niri
info "Ensuring xdg-desktop-portal-gnome is installed (provider for Niri)"
sudo pacman -S --needed --noconfirm xdg-desktop-portal-gnome; or die "failed installing xdg-desktop-portal-gnome"

# Core packages
info "Installing core packages via pacman"
set -l CORE_PKGS niri ghostty cliphist base-devel micro fuzzel zen-browser quickshell nautilus sddm gvfs udisks2 polkit polkit-gnome cava xwayland-satellite playerctl hyprlock haruna htop nvtop xdg-desktop-portal-gnome gnome-keyring swww nm-connection-editor network-manager-applet swaync ttf-jetbrains-mono-nerd gnome-text-editor kvantum kvantum-qt5 qt6ct qt5ct hyprpicker ttf-jetbrains-mono-nerd ttf-jetbrains-mono woff2-font-awesome otf-font-awesome rust gimp xdg-desktop-portal-kde dolphin kio kio-extras kde-cli-tools desktop-file-utils shared-mime-info archlinux-xdg-menu xdg-utils kcalc gnome-session
if test $DO_HYPR -eq 1
    set CORE_PKGS $CORE_PKGS hyprland
end
sudo pacman -S --needed --noconfirm $CORE_PKGS; or die "pacman core packages failed"

info "Enable and start udisks2"
sudo systemctl enable --now udisks2; or warn "udisks2 enable failed"

# Polkit agent systemd user service
info "Setting up polkit agent as user service"
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & disown; or true
mkdir -p ~/.config/systemd/user; or die "cannot create user systemd dir"
sudo rsync -a $CELONA_DIR/.systemd/polkit-agent.service ~/.config/systemd/user/polkit-agent.service; or die "polkit-agent.service sync failed"
systemctl --user daemon-reload; or warn "user daemon-reload failed"
systemctl --user enable --now polkit-agent.service; or warn "enable polkit-agent failed"
systemctl --user add-wants niri.service polkit-agent.service; or true
sudo systemctl enable sddm.service; or warn "enable sddm failed"

# Portals config
info "Applying portals config for niri"
sudo rsync -a $CELONA_DIR/.portal/niri-portals.conf /usr/share/xdg-desktop-portal/niri-portals.conf; or warn "portal config sync failed"
systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gtk.service xdg-desktop-portal-gnome.service plasma-xdg-desktop-portal-kde.service; or warn "portal services restart failed"

# MIME and menu caches
info "Updating desktop databases and KDE sycoca"
sudo update-desktop-database; or true
env XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental; or true

# Paru and AUR packages (always install as per scriptinput)
if not command -q paru
    warn "paru not found. Build and install paru from AUR now?"
    if confirm "Install paru now (requires base-devel)?"
        set -l TMPPARU (mktemp -d)
        pushd $TMPPARU >/dev/null
        git clone https://aur.archlinux.org/paru.git; or die "clone paru failed"
        pushd paru >/dev/null
        makepkg -si --noconfirm; or die "makepkg paru failed"
        popd >/dev/null
        popd >/dev/null
        rm -rf $TMPPARU
    else
        die "paru is required to install AUR packages. Aborting."
    end
end

if test -f $CELONA_DIR/.paru/paru.conf
    info "Syncing /etc/paru.conf from Celona repo"
    sudo rsync -a $CELONA_DIR/.paru/paru.conf /etc/paru.conf; or warn "paru.conf sync failed"
end
info "Refreshing AUR packages"
paru -Syu --noconfirm; or warn "paru -Syu failed"
info "Installing AUR packages (sddm-silent-theme bibata-cursor-theme-bin nwg-look kora-icon-theme mpvpaper matugen)"
paru -S --noconfirm --needed --skipreview --removemake --cleanafter sddm-silent-theme bibata-cursor-theme-bin nwg-look kora-icon-theme mpvpaper matugen; or warn "AUR package install failed"

# Hyprgreetr build and install
info "Building and installing hyprgreetr"
set -l HYPRTMP (mktemp -d)
pushd $HYPRTMP >/dev/null
git clone https://github.com/myinqi/hyprgreetr.git; or die "clone hyprgreetr failed"
pushd hyprgreetr >/dev/null
cargo build --release; or die "cargo build hyprgreetr failed"
cargo install --path .; or die "cargo install hyprgreetr failed"
fish_add_path ~/.cargo/bin; or true
# Optional: run hyprgreetr once as in scriptinput
hyprgreetr & disown; or true
# Initialize default assets if present
if test -d assets
    mkdir -p ~/.config/hyprgreetr/pngs/
    rsync -a assets/ ~/.config/hyprgreetr/pngs/
end
popd >/dev/null
popd >/dev/null
rm -rf $HYPRTMP

# Fish configs
info "Sync fish shell configs"
sudo rsync -a $CELONA_DIR/.fish/config.fish ~/.config/fish/config.fish; or warn "user fish config sync failed"
sudo rsync -a $CELONA_DIR/.fish/cachyos-config.fish /usr/share/cachyos-fish-config/cachyos-config.fish; or warn "cachyos fish config sync failed"

# Theme settings (best-effort)
info "Applying theme settings"
command -q gsettings; and begin
    gsettings set org.gnome.desktop.interface icon-theme 'kora-pgrey'; or true
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'; or true
    gsettings set org.gnome.desktop.interface cursor-size 28; or true
end
command -q kwriteconfig6; and kwriteconfig6 --file kdeglobals --group Icons --key Theme "kora-pgrey"; or true
kbuildsycoca6 --noincremental; or true

# Celona configuration sync
info "Syncing Celona configuration"
sudo rsync -a $CELONA_DIR/.sddm_conf/sddm.conf /etc/sddm.conf; or warn "sddm.conf sync failed"
rsync -a $CELONA_DIR/.config/ ~/.config/; or warn "user .config sync failed"
sudo rsync -a $CELONA_DIR/.sddm_conf/metadata.desktop /usr/share/sddm/themes/silent/metadata.desktop; or warn "metadata.desktop sync failed"
sudo rsync -a $CELONA_DIR/.sddm_conf/celona.conf /usr/share/sddm/themes/silent/configs/; or warn "celona.conf sync failed"
sudo rsync -a $CELONA_DIR/wallpapers/3440x1440/ /usr/share/sddm/themes/silent/backgrounds/; or warn "wallpapers sync failed"
sudo rsync -a $CELONA_DIR/.environment/environment /etc/environment; or warn "/etc/environment sync failed"
if test -f ~/.config/fuzzel/install-pickers.sh
    bash ~/.config/fuzzel/install-pickers.sh; or warn "fuzzel pickers install failed"
end

# Snapper: re-enable timers post install, optionally create post snapshots
if test $DO_BTRFS -eq 1
    info "Re-enabling snapper timers"
    sudo snapper -c home set-config TIMELINE_CREATE=no; or true
    sudo systemctl enable --now snapper-timeline.timer; or warn "enable snapper-timeline failed"
    sudo systemctl enable --now snapper-cleanup.timer; or warn "enable snapper-cleanup failed"
end

# Final hints
set -l MSG "Installation complete. Notes:\n- Adjust ~/.config/niri/config.kdl (keyboard layout, resolution/refresh rate, max width).\n- Log out/in or reboot to apply SDDM/portals.\n- Customize ~/.config/hyprgreetr/config.toml.\n- Set a wallpaper and briefly toggle dark/light theme to trigger Matugen."

echo -e $MSG

if confirm "Reboot now to complete installation?"
    sudo reboot
else
    info "No reboot performed. Please reboot later."
end
