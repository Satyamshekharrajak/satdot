#!/usr/bin/env bash
set -e

echo "[1/10] Stopping services..."
systemctl stop NetworkManager || true
systemctl stop apparmor || true
systemctl stop tlp || true
systemctl stop libvirtd || true

echo "[2/10] Removing packages..."
pacman -Rns --noconfirm \
    hyprland waybar hyprpaper rofi-wayland \
    wl-clipboard cliphist \
    dunst grim slurp \
    thunar gvfs tumbler \
    kitty \
    pipewire pipewire-pulse wireplumber \
    pavucontrol \
    networkmanager systemd-resolvconf \
    ufw apparmor firejail \
    qemu-full virt-manager virt-viewer \
    zram-generator tlp \
    intel-media-driver vulkan-intel \
    brave-bin firefox \
    gcc g++ make cmake rust go python nodejs npm jdk17-openjdk \
    timeshift fastfetch btop

echo "[3/10] Removing configs..."
rm -rf /home/*/.config/hypr
rm -rf /home/*/.config/waybar
rm -rf /home/*/.config/rofi
rm -rf /home/*/.config/kitty
rm -rf /home/*/.config/wallpapers

echo "[4/10] Removing kernel tweaks..."
rm -f /etc/sysctl.d/99-shadowarch.conf
sysctl --system || true

echo "[5/10] Removing ZRAM config..."
rm -f /etc/systemd/zram-generator.conf

echo "[6/10] Removing KVM modules..."
rm -f /etc/modules-load.d/kvm.conf

echo "[7/10] Removing DNS-over-TLS config..."
sed -i 's/DNSOverTLS=yes/#DNSOverTLS=yes/' /etc/systemd/resolved.conf

echo "[8/10] Cleaning package cache..."
pacman -Scc --noconfirm

echo "[10/10] UNDO completed — system restored to minimal Arch."
