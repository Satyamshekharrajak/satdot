#!/usr/bin/env bash
set -e

# ==============================================================================
# 0. SAFETY CHECK
# ==============================================================================
if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: Run with sudo."
  exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
CONFIG_DIR="$USER_HOME/.config"

echo "
==================================================
        SHADOWARCH — FINAL SETUP v4.1
==================================================
"

# ==============================================================================
# 1. SYSTEM PREP
# ==============================================================================
echo "[1/25] Updating system + enabling parallel downloads..."
sed -i 's/^#ParallelDownloads/ParallelDownloads = 10/' /etc/pacman.conf
pacman -Syu --noconfirm

echo "[2/25] Installing core system packages..."
pacman -S --noconfirm \
    base-devel git wget curl jq fastfetch chafa \
    networkmanager systemd-resolvconf dbus polkit-gnome \
    xdg-user-dirs xdg-utils \
    linux linux-headers \
    ufw apparmor zram-generator tlp \
    pipewire pipewire-pulse wireplumber pipewire-alsa alsa-utils \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji \
    qt5-wayland qt6-wayland \
    sddm

systemctl enable --now NetworkManager
systemctl enable --now systemd-resolved || true
systemctl enable --now apparmor
systemctl enable --now tlp
systemctl enable --now sddm

ufw default deny incoming
ufw default allow outgoing
ufw --force enable

sudo -u "$REAL_USER" xdg-user-dirs-update

# ==============================================================================
# 2. AUR HELPER (PARU)
# ==============================================================================
echo "[3/25] Installing PARU (AUR helper)..."
if ! sudo -u "$REAL_USER" command -v paru &>/dev/null; then
    TMP=$(mktemp -d)
    chown "$REAL_USER":"$REAL_USER" "$TMP"
    sudo -u "$REAL_USER" bash <<EOF
        cd "$TMP"
        git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin
        makepkg -si --noconfirm
EOF
fi

# ==============================================================================
# 3. HYPERLAND + UI STACK
# ==============================================================================
echo "[4/25] Installing Hyprland stack..."
sudo -u "$REAL_USER" paru -S --noconfirm \
    hyprland \
    waybar hyprpaper \
    dunst wl-clipboard cliphist \
    grim slurp \
    rofi-wayland \
    thunar kitty \
    papirus-icon-theme bibata-cursor-theme \
    catppuccin-gtk-theme-mocha \
    brave-bin firefox \
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

# ==============================================================================
# 4. WALLPAPERS
# ==============================================================================
echo "[5/25] Creating directories + downloading wallpapers..."
sudo -u "$REAL_USER" mkdir -p "$CONFIG_DIR"/{hypr/scripts,waybar,kitty,rofi,dunst,wallpapers/fullpack}

WALLDIR="$CONFIG_DIR/wallpapers/fullpack"

urls=(
"https://raw.githubusercontent.com/sylveonlol/wallpapers/main/cyberpunk-anime/cyber-anime1.png"
"https://raw.githubusercontent.com/sylveonlol/wallpapers/main/cyberpunk-anime/cyber-anime2.jpg"
"https://raw.githubusercontent.com/sylveonlol/wallpapers/main/cyberpunk-anime/cyber-anime4.jpg"
"https://raw.githubusercontent.com/catppuccin/wallpapers/main/simple/mocha-wave.png"
"https://raw.githubusercontent.com/catppuccin/wallpapers/main/simple/mocha-grid.png"
)

for url in "${urls[@]}"; do
    sudo -u "$REAL_USER" wget -q "$url" -P "$WALLDIR" || true
done

DEFAULT_WALL=$(ls "$WALLDIR" | shuf -n 1)

# ==============================================================================
# 5. WAYBAR
# ==============================================================================
echo "[6/25] Configuring Waybar..."
sudo -u "$REAL_USER" tee "$CONFIG_DIR/waybar/colors.css" >/dev/null <<EOF
@define-color bg #1e1e2e;
@define-color fg #cdd6f4;
@define-color accent #89dceb;
EOF

sudo -u "$REAL_USER" tee "$CONFIG_DIR/waybar/style.css" >/dev/null <<EOF
@import "colors.css";
* { 
  font-family: "JetBrainsMono Nerd Font"; 
  font-size: 14px; 
}
window#waybar { 
  background: rgba(30,30,46,0.6); 
  backdrop-filter: blur(7px); 
}
#workspaces button.active { 
  color: @accent; 
}
#cpu,#memory,#clock,#pulseaudio {
  background: rgba(49,50,68,0.6);
  padding: 0 12px;
  margin: 4px;
  border-radius: 12px;
}
EOF

sudo -u "$REAL_USER" tee "$CONFIG_DIR/waybar/config" >/dev/null <<EOF
{
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["cpu","memory","pulseaudio"],
  "clock": { "format": "{:%H:%M:%S}" },
  "hyprland/workspaces": {
    "format": "{icon}",
    "format-icons": {
      "1":"イチ","2":"ニ","3":"サン","4":"ヨン","5":"ゴ",
      "6":"ロク","7":"ナナ","8":"ハチ","9":"キュウ","10":"ジュウ"
    },
    "persistent-workspaces": {"*": 10}
  }
}
EOF

# ==============================================================================
# 6. DUNST
# ==============================================================================
echo "[7/25] Setting up Dunst..."
sudo -u "$REAL_USER" tee "$CONFIG_DIR/dunst/dunstrc" >/dev/null <<EOF
[global]
font = JetBrainsMono Nerd Font 12
background = "#1e1e2e"
foreground = "#cdd6f4"
frame_color = "#89dceb"
separator_color = frame
EOF

# ==============================================================================
# 7. KITTY
# ==============================================================================
echo "[8/25] Configuring Kitty..."
sudo -u "$REAL_USER" tee "$CONFIG_DIR/kitty/kitty.conf" >/dev/null <<EOF
font_family JetBrainsMono Nerd Font
font_size 12
background #1e1e2e
foreground #cdd6f4
cursor #89dceb
EOF

# ==============================================================================
# 8. ROFI
# ==============================================================================
echo "[9/25] Configuring Rofi..."
sudo -u "$REAL_USER" tee "$CONFIG_DIR/rofi/config.rasi" >/dev/null <<EOF
configuration {
  show-icons: true;
  font: "JetBrainsMono Nerd Font 13";
}
@theme "/dev/null"
* { 
  bg: #1e1e2e; 
  fg: #cdd6f4; 
  accent: #89dceb; 
}
window { 
  background-color: @bg; 
  border: 2px solid @accent;
  border-radius: 12px; 
}
EOF

# ==============================================================================
# 9. HYPERLAND CONFIG
# ==============================================================================
echo "[10/25] Writing Hyprland config..."

sudo -u "$REAL_USER" tee "$CONFIG_DIR/hypr/hyprland.conf" >/dev/null <<EOF
monitor=,preferred,auto,1

env = XCURSOR_SIZE=24
env = QT_QPA_PLATFORM=wayland
env = GDK_BACKEND=wayland

exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
exec-once = hyprpaper &
exec-once = waybar &

general {
  gaps_in = 10
  gaps_out = 20
  border_size = 3
  col.active_border = rgb(89dceb)
  col.inactive_border = rgb(313244)
}

decoration {
  rounding = 10
  blur {
    enabled = true
    size = 7
    passes = 2
  }
  shadow_range = 20
  drop_shadow = true
}

animations {
  enabled = true
  animation = windows,1,7,default
  animation = fade,1,4,default
  animation = border,1,3,default
}

\$mod = SUPER

bind = \$mod, RETURN, exec, kitty
bind = \$mod, D, exec, rofi -show drun
bind = \$mod, Q, killactive
EOF

for i in {1..9}; do
  echo "bind = \$mod, $i, workspace, $i" | sudo -u "$REAL_USER" tee -a "$CONFIG_DIR/hypr/hyprland.conf"
done
echo "bind = \$mod, 0, workspace, 10" | sudo -u "$REAL_USER" tee -a "$CONFIG_DIR/hypr/hyprland.conf"

# ==============================================================================
# 10. HYPREPAPER CONFIG
# ==============================================================================
echo "[11/25] Configuring Hyprpaper..."
sudo -u "$REAL_USER" tee "$CONFIG_DIR/hypr/hyprpaper.conf" >/dev/null <<EOF
preload = $WALLDIR/$DEFAULT_WALL
wallpaper = ,$WALLDIR/$DEFAULT_WALL
EOF

# ==============================================================================
# 11. ANIME ASCII FETCH
# ==============================================================================
echo "[12/25] Setting up Anime Fastfetch..."
sudo -u "$REAL_USER" tee "$CONFIG_DIR/hypr/scripts/anime-fetch.sh" >/dev/null <<'EOF'
#!/usr/bin/env bash
DIR="$HOME/.config/wallpapers/fullpack"
IMG=$(find "$DIR" -type f | shuf -n 1)
fastfetch --logo "$IMG" --logo-type kitty --logo-width 28 --logo-height 12
EOF

chmod +x "$CONFIG_DIR/hypr/scripts/anime-fetch.sh"

echo "~/.config/hypr/scripts/anime-fetch.sh" >> "$USER_HOME/.bashrc"

# ==============================================================================
# 12. SDDM THEME
# ==============================================================================
echo "[13/25] Installing SDDM theme..."
THEMEDIR="/usr/share/sddm/themes/ShadowArch"
mkdir -p "$THEMEDIR"

cp "$WALLDIR/$DEFAULT_WALL" "$THEMEDIR/background.png"

tee "$THEMEDIR/theme.conf" >/dev/null <<EOF
[General]
background=background.png
font=JetBrains Mono
accentColor=#89dceb
EOF

mkdir -p /etc/sddm.conf.d
tee /etc/sddm.conf.d/theme.conf >/dev/null <<EOF
[Theme]
Current=ShadowArch
EOF

# ==============================================================================
# 13. FIX PERMISSIONS
# ==============================================================================
echo "[14/25] Fixing permissions..."
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME"

# ==============================================================================
# DONE
# ==============================================================================
echo "
==================================================
      SHADOWARCH INSTALL COMPLETE v4.1 ✔
==================================================
 Reboot → Login → Choose “Hyprland”
==================================================
"
