#!/usr/bin/env bash
set -e

# ==============================================================================
# 0. SAFETY CHECK & ENVIRONMENT
# ==============================================================================
if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: Please run with sudo."
  exit 1
fi

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
CONFIG_DIR="$USER_HOME/.config"

echo "
==================================================
   SHADOWARCH MASTER SETUP (VERSION 3.0)
==================================================
"

# ==============================================================================
# 1. SYSTEM OPTIMIZATION & CORE
# ==============================================================================
echo "[1/12] Optimizing pacman and system update..."
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -Syu --noconfirm

echo "[2/12] Installing core system packages..."
pacman -S --noconfirm \
    base-devel git wget curl jq chafa fastfetch \
    networkmanager systemd-resolved dbus \
    xdg-user-dirs xdg-utils polkit-gnome \
    pipewire pipewire-pulse wireplumber alsa-utils \
    ufw apparmor zram-generator tlp \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji \
    linux linux-headers qt5-wayland qt6-wayland sddm

# Enable Essential Services
systemctl enable --now NetworkManager systemd-resolved apparmor tlp sddm
systemctl enable ufw
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

sudo -u "$REAL_USER" xdg-user-dirs-update

# ==============================================================================
# 2. AUR HELPER (PARU)
# ==============================================================================
echo "[3/12] Installing PARU (AUR helper)..."
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
# 3. HYPRLAND & VISUAL STACK
# ==============================================================================
echo "[4/12] Installing Hyprland stack & Themes..."
sudo -u "$REAL_USER" paru -S --noconfirm \
    hyprland waybar hyprpaper \
    wl-clipboard cliphist dunst grim slurp \
    rofi-wayland thunar kitty \
    papirus-icon-theme bibata-cursor-theme \
    xdg-desktop-portal xdg-desktop-portal-hyprland \
    brave-bin catppuccin-gtk-theme-mocha

# ==============================================================================
# 4. CONFIGURATION & DIRECTORIES
# ==============================================================================
echo "[5/12] Setting up directories and wallpapers..."
sudo -u "$REAL_USER" mkdir -p "$CONFIG_DIR"/{hypr/scripts,waybar,kitty,rofi,wallpapers/fullpack}

WALLDIR="$CONFIG_DIR/wallpapers/fullpack"
urls=(
"https://raw.githubusercontent.com/sylveonlol/wallpapers/main/cyberpunk-anime/cyber-anime1.png"
"https://raw.githubusercontent.com/sylveonlol/wallpapers/main/cyberpunk-anime/cyber-anime3.png"
"https://raw.githubusercontent.com/catppuccin/wallpapers/main/simple/mocha-wave.png"
)

for url in "${urls[@]}"; do
    sudo -u "$REAL_USER" wget -q "$url" -P "$WALLDIR" || true
done

DEFAULT_WALL=$(ls "$WALLDIR" | head -n 1)
EXT="${DEFAULT_WALL##*.}"

# ==============================================================================
# 5. WRITING THEME & CONFIG FILES
# ==============================================================================
echo "[6/12] Configuring Terminal & Launcher..."

# Kitty Config
sudo -u "$REAL_USER" tee "$CONFIG_DIR/kitty/kitty.conf" >/dev/null <<EOF
font_family      JetBrainsMono Nerd Font
font_size        11.0
window_padding_width 15
background       #1e1e2e
foreground       #cdd6f4
EOF

# Rofi Config (Mocha Theme)
sudo -u "$REAL_USER" tee "$CONFIG_DIR/rofi/config.rasi" >/dev/null <<EOF
configuration { modi: "drun"; show-icons: true; font: "JetBrainsMono Nerd Font 12"; }
@theme "/dev/null"
* { bg: #1e1e2e; fg: #cdd6f4; accent: #89dceb; }
window { background-color: @bg; border: 2px; border-color: @accent; border-radius: 12px; width: 30%; }
element selected { background-color: @accent; text-color: @bg; }
EOF

# Hyprland Config
echo "[7/12] Configuring Hyprland..."
sudo -u "$REAL_USER" tee "$CONFIG_DIR/hypr/hyprland.conf" >/dev/null <<EOF
monitor=,preferred,auto,1
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland
env = GDK_BACKEND,wayland,x11

exec-once = waybar
exec-once = hyprpaper
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

\$mod = SUPER
bind = \$mod, RETURN, exec, kitty
bind = \$mod, D, exec, rofi -show drun -theme $CONFIG_DIR/rofi/config.rasi
bind = \$mod, Q, killactive
bind = \$mod, F1, exec, $CONFIG_DIR/hypr/scripts/keybinds.sh
bind = \$mod SHIFT, W, exec, $USER_HOME/shadow-wallpaper.sh \$(find $WALLDIR -type f | shuf -n 1)

$(for i in {1..9}; do echo "bind = \$mod, $i, workspace, $i"; done)
bind = \$mod, 0, workspace, 10
EOF

# ==============================================================================
# 6. SCRIPTS & MAINTENANCE
# ==============================================================================
echo "[8/12] Generating helper scripts..."

# Keybinds script
sudo -u "$REAL_USER" tee "$CONFIG_DIR/hypr/scripts/keybinds.sh" >/dev/null <<'EOF'
#!/usr/bin/env bash
grep '^bind =' ~/.config/hypr/hyprland.conf | sed 's/bind = //g' | rofi -dmenu -i -p "Keys" -theme ~/.config/rofi/config.rasi
EOF

# Wallpaper script
sudo -u "$REAL_USER" tee "$USER_HOME/shadow-wallpaper.sh" >/dev/null <<EOF
#!/usr/bin/env bash
NEW_WALL=\$1
hyprctl hyprpaper preload "\$NEW_WALL"
hyprctl hyprpaper wallpaper ",\$NEW_WALL"
EOF

chmod +x "$CONFIG_DIR/hypr/scripts/keybinds.sh" "$USER_HOME/shadow-wallpaper.sh"

# ==============================================================================
# 7. SDDM & SHELL POLISH
# ==============================================================================
echo "[9/12] Setting up SDDM Login Screen..."
THEMEDIR="/usr/share/sddm/themes/ShadowArch"
mkdir -p "$THEMEDIR"
cp "$WALLDIR/$DEFAULT_WALL" "$THEMEDIR/background.$EXT"
echo "[General]
background=background.$EXT
font=JetBrains Mono
accentColor=#89dceb" > "$THEMEDIR/theme.conf"

mkdir -p /etc/sddm.conf.d
echo "[Theme]
Current=ShadowArch" > /etc/sddm.conf.d/theme.conf

# Bashrc Fetch
if ! grep -q "fastfetch" "$USER_HOME/.bashrc"; then
    echo "fastfetch --logo-type kitty --logo-width 28" >> "$USER_HOME/.bashrc"
fi

# Hyprpaper startup file
sudo -u "$REAL_USER" echo "preload = $WALLDIR/$DEFAULT_WALL
wallpaper = ,$WALLDIR/$DEFAULT_WALL" > "$CONFIG_DIR/hypr/hyprpaper.conf"

# ==============================================================================
# 8. PERMISSIONS & FINISH
# ==============================================================================
echo "[10/12] Fixing ownership..."
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME"

echo "
==================================================
   SHADOWARCH SETUP COMPLETE ✔
==================================================
   1. Reboot your system.
   2. At the login screen, select 'Hyprland'.
   3. Press SUPER + RETURN to open terminal.
   4. Press SUPER + F1 for help.
==================================================
"
