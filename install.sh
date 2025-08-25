#!/usr/bin/env bash
set -e

echo "[*] Starting custom Arch/Hyprland setup..."

# === 1. Install system packages with yay ===
echo "[*] Installing base packages..."
yay -S --needed --noconfirm \
    base-devel brightnessctl network-manager-applet konsole blueman ark dolphin ffmpegthumbs \
    playerctl kvantum polkit-kde-agent jq gufw tar gammastep wl-clipboard easyeffects \
    hyprpicker hyprshot-git bc sysstat kitty sassc systemsettings acpi fish \
    kde-material-you-colors plasma5support plasma5-integration plasma-framework5 \
    ttf-jetbrains-mono-nerd ttf-fantasque-nerd powerdevil power-profiles-daemon \
    libjpeg6-turbo swww python-regex copyq quickshell

# Optional apps
echo "[*] Installing optional apps..."
yay -S --needed --noconfirm \
    orchis-theme-git visual-studio-code-bin nwg-look-bin qt5ct strawberry

# === 2. Python deps for depth effect in a venv ===
echo "[*] Setting up temp Python environment for rembg..."
mkdir -p ~/.local/envs
python -m venv ~/.local/envs/rembg-env
source ~/.local/envs/rembg-env/bin/activate
pip install --upgrade pip
pip install "rembg[gpu]" pillow
deactivate
echo "[*] Installed rembg + pillow in ~/.local/envs/rembg-env"

# === 3. Clone NibrasShell ===
echo "[*] Cloning NibrasShell repo..."
git clone https://github.com/AhmedSaadi0/NibrasShell.git ~/NibrasShell || true

# === 4. Backup existing configs ===
echo "[*] Backing up old configs..."
mkdir -p ~/.config/fish
[ -d ~/.config/hypr ] && mv ~/.config/hypr ~/.config/hypr-old
[ -d ~/.config/quickshell ] && mv ~/.config/quickshell ~/.config/quickshell-old
[ -d ~/.config/wofi ] && mv ~/.config/wofi ~/.config/wofi-old
[ -d ~/.config/easyeffects ] && mv ~/.config/easyeffects ~/.config/easyeffects-old
[ -f ~/.config/fish/config.fish ] && cp ~/.config/fish/config.fish ~/.config/fish/config.back.fish

# === 5. Copy configs from repo ===
echo "[*] Copying configs..."
cp -r ~/NibrasShell/my-hyprland-config ~/.config/hypr
cp -r ~/.config/hypr/config/quickshell ~/.config/quickshell
cp -r ~/.config/hypr/config/wofi ~/.config/wofi
cp ~/.config/hypr/config/config.fish ~/.config/fish/config.fish

# === 6. Scripts permissions ===
echo "[*] Setting executable permissions..."
chmod +x ~/.config/hypr/scripts/* || true
chmod +x ~/.config/quickshell/scripts/* || true

# === 7. Easyeffects config ===
echo "[*] Copying easyeffects config..."
cp -r ~/.config/hypr/config/easyeffects ~/.config/easyeffects

# === 8. Themes and color schemes ===
echo "[*] Copying theme/color files..."
mkdir -p ~/.local/share/color-schemes \
         ~/.local/share/konsole \
         ~/.config/Kvantum \
         ~/.config/qt5ct \
         ~/.config/qt6ct

cp -r ~/.config/hypr/config/plasma-colors/* ~/.local/share/color-schemes/
cp -r ~/.config/hypr/config/kvantum-themes/* ~/.config/Kvantum/
cp -r ~/.config/hypr/config/konsole/* ~/.local/share/konsole/
cp ~/.config/hypr/config/qt5ct.conf ~/.config/qt5ct/
cp ~/.config/hypr/config/qt6ct.conf ~/.config/qt6ct/

# === 9. GTK themes ===
echo "[*] Extracting GTK themes..."
mkdir -p ~/.themes
cp -r ~/NibrasShell/config/gtk-themes/* ~/.themes/

# === 10. Fonts ===
echo "[*] Copying fonts..."
mkdir -p ~/.fonts
cp -r ~/.config/hypr/config/.fonts/* ~/.fonts

# === 11. Icons ===
echo "[*] Extracting icons..."
mkdir -p ~/.local/share/icons
for ICON in ~/.config/hypr/config/icons/*.tar.gz; do
    tar xvf "$ICON" -C ~/.local/share/icons
done

echo "[*] Done! 🎉 You can now log out and back in."
