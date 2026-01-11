#!/usr/bin/env bash
set -e

### ============================================================
### SHADOWARCH – FULL AUTO-INSTALL + CONFIG SCRIPT
### COMPETE WAYLAND/HYPERLAND + SECURITY + PERFORMANCE SYSTEM
### ============================================================

USERNAME=${SUDO_USER:-$USER}
HOME_DIR="/home/$USERNAME"

echo "[1/30] Updating system..."
pacman -Syu --noconfirm

### ------------------------------------------------------------
### CORE SYSTEM
### ------------------------------------------------------------

echo "[2/30] Installing core packages..."
pacman -S --noconfirm \
    base-devel git wget curl neovim nano \
    linux linux-headers linux-hardened \
    networkmanager systemd-resolvconf \
    ufw apparmor firejail \
    zram-generator rsync zip unzip p7zip unrar \
    ntfs-3g bash-completion logrotate \
    mesa vulkan-intel intel-media-driver intel-gpu-tools \
    fastfetch btop htop \
    timeshift \
    xdg-user-dirs xdg-utils

### Enable services
echo "[3/30] Enabling services..."
systemctl enable NetworkManager
systemctl enable systemd-resolved
systemctl enable apparmor
systemctl enable ufw
systemctl enable logrotate.timer

### ------------------------------------------------------------
### FIREWALL + SECURITY
### ------------------------------------------------------------
echo "[4/30] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

echo "[5/30] Applying kernel hardening..."
cat <<EOF >/etc/sysctl.d/99-shadowarch.conf
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.yama.ptrace_scope=2
fs.protected_fifos=1
fs.protected_hardlinks=1
fs.protected_symlinks=1
EOF
sysctl --system

### ------------------------------------------------------------
### PERFORMANCE
### ------------------------------------------------------------

echo "[6/30] Setting up ZRAM..."
cat <<EOF >/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
EOF

echo "[7/30] Installing TLP power management..."
pacman -S --noconfirm tlp
systemctl enable --now tlp

### ------------------------------------------------------------
### DNS OVER TLS
### ------------------------------------------------------------

echo "[8/30] Enabling DNS-over-TLS..."
sed -i 's/#DNSOverTLS=.*/DNSOverTLS=yes/' /etc/systemd/resolved.conf

### ------------------------------------------------------------
### WAYLAND + HYPERLAND DESKTOP
### ------------------------------------------------------------

echo "[9/30] Installing Wayland/Hyperland..."
pacman -S --noconfirm \
    hyprland waybar hyprpaper \
    wl-clipboard cliphist \
    dunst \
    grim slurp \
    rofi-wayland \
    thunar gvfs tumbler \
    kitty \
    papirus-icon-theme bibata-cursor-theme \
    xdg-desktop-portal-hyprland

### ------------------------------------------------------------
### AUDIO SYSTEM
### ------------------------------------------------------------

echo "[10/30] Installing PipeWire..."
pacman -S --noconfirm \
    pipewire pipewire-pulse wireplumber pavucontrol

### ------------------------------------------------------------
### DEVELOPER STACK (FULL)
### ------------------------------------------------------------

echo "[11/30] Installing development languages..."
pacman -S --noconfirm \
    gcc g++ make cmake \
    python python-pip \
    nodejs npm \
    rust go \
    jdk17-openjdk \
    git

### ------------------------------------------------------------
### BROWSERS
### ------------------------------------------------------------

echo "[12/30] Installing browsers..."
pacman -S --noconfirm firefox brave-bin || true

### ------------------------------------------------------------
### VIRTUALIZATION (KVM + GPU ACCEL)
### ------------------------------------------------------------

echo "[13/30] Installing KVM/QEMU virtualization..."
pacman -S --noconfirm \
    qemu-full virt-manager virt-viewer dnsmasq iptables-nft

echo "kvm" >/etc/modules-load.d/kvm.conf
echo "kvm-intel" >>/etc/modules-load.d/kvm.conf

systemctl enable --now libvirtd
usermod -aG libvirt "$USERNAME"

### ------------------------------------------------------------
### THEME & CONFIGS (HYDE)
### ------------------------------------------------------------

echo "[14/30] Creating config directories..."
mkdir -p $HOME_DIR/.config/{hypr,waybar,rofi,kitty,wallpapers}

### ---- Hyperland Config ----
echo "[15/30] Installing Hyperland config..."
cat <<'EOF' >$HOME_DIR/.config/hypr/hyprland.conf
monitor=,preferred,auto,1
exec-once=waybar
exec-once=dunst
exec-once=hyprpaper
exec-once=wl-paste -t text --watch cliphist store

general {
    gaps_in = 7
    gaps_out = 15
    border_size = 3
    col.active_border = rgb(c6a0f6)
    col.inactive_border = rgb(313244)
    rounding = 10
}

decoration {
    rounding = 10
    blur { enabled = true; size = 8; passes = 2; }
    drop_shadow = true
    shadow_range = 20
    shadow_render_power = 3
}

input { kb_layout = us }

bind = SUPER, RETURN, exec, kitty
bind = SUPER, E, exec, thunar
bind = SUPER, D, exec, rofi -show drun
bind = SUPER, Q, killactive
bind = SUPER, F, togglefloating
bind = SUPER SHIFT, R, exec, hyprctl reload
EOF

### Wallpaper
wget -O $HOME_DIR/.config/wallpapers/hyde.png \
https://raw.githubusercontent.com/catppuccin/wallpapers/main/gradient-mocha.png

cat <<EOF >$HOME_DIR/.config/hypr/hyprpaper.conf
preload = $HOME_DIR/.config/wallpapers/hyde.png
wallpaper = ,$HOME_DIR/.config/wallpapers/hyde.png
EOF

### ---- Waybar ----
echo "[16/30] Installing Waybar..."
cat <<'EOF' >$HOME_DIR/.config/waybar/config
{
  "layer": "top",
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["cpu","memory","network","pulseaudio","battery"],
  "clock": { "format": "{:%a %d %b  %H:%M}" }
}
EOF

cat <<'EOF' >$HOME_DIR/.config/waybar/style.css
* { font-family: "JetBrainsMono Nerd Font"; font-size: 12px; }
window#waybar {
    background: rgba(30,30,46,0.8);
    border-bottom: 2px solid #89dceb;
    color: #cdd6f4;
}
#workspaces button {
    padding: 4px 6px; margin: 3px;
    background: #313244; color: #89dceb;
    border-radius: 8px;
}
#workspaces button.active {
    background: #89dceb; color: #1e1e2e;
}
#cpu,#memory,#network,#pulseaudio,#battery,#clock {
    padding: 5px 10px; margin-right: 6px;
    background: #313244; border-radius: 8px;
}
EOF

### ---- Rofi ----
echo "[17/30] Installing Rofi theme..."
cat <<'EOF' >$HOME_DIR/.config/rofi/config.rasi
configuration {
  font: "JetBrainsMono Nerd Font 14";
}
@theme "catppuccin-mocha"
EOF

### ---- Kitty ----
echo "[18/30] Installing Kitty config..."
cat <<'EOF' >$HOME_DIR/.config/kitty/kitty.conf
font_family JetBrains Mono
font_size 12
background #1e1e2e
foreground #cdd6f4
cursor     #89dceb
selection_bg #313244
EOF

### Permissions
echo "[19/30] Fixing permissions..."
chown -R $USERNAME:$USERNAME $HOME_DIR/.config

### ------------------------------------------------------------
### FINAL SYSTEM CLEANUP
### ------------------------------------------------------------

echo "[20/30] Enabling parallel downloads..."
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

echo "[21/30] Cleaning package cache..."
pacman -Scc --noconfirm

echo "[30/30] ShadowArch installation COMPLETE!"
echo "Reboot & login to Hyperland."
