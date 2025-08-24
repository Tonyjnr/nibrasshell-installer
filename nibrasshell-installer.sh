#!/bin/bash

# NibrasShell Installation Script
# Automated installer for NibrasShell Hyprland configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root"
fi

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    error "yay AUR helper is required but not installed. Please install yay first."
fi

# Function to check if package is installed
is_installed() {
    yay -Qi "$1" &> /dev/null
}

# Function to install packages with better error handling
install_packages() {
    local packages=("$@")
    local to_install=()
    local failed_packages=()
    
    log "Checking which packages need to be installed..."
    for package in "${packages[@]}"; do
        if ! is_installed "$package"; then
            to_install+=("$package")
        else
            log "$package is already installed"
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        log "Installing packages: ${to_install[*]}"
        
        # Ensure sudo credentials are cached properly
        log "Authenticating for package installation..."
        if ! sudo -v; then
            error "Authentication failed"
            exit 1
        fi
        
        # Try installing all packages first
        if ! timeout 1800 yay -S --needed --noconfirm "${to_install[@]}" 2>/dev/null; then
            warn "Batch installation failed or timed out. Trying individual installation..."
            
            # Install packages individually to identify problematic ones
            for package in "${to_install[@]}"; do
                log "Installing $package individually..."
                # Refresh sudo credentials before each package
                sudo -v 2>/dev/null
                if ! timeout 600 yay -S --needed --noconfirm "$package" 2>/dev/null; then
                    error "Failed to install $package"
                    failed_packages+=("$package")
                    
                    # Ask user if they want to continue
                    read -p "Continue without $package? (Y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Nn]$ ]]; then
                        error "Installation cancelled by user"
                        exit 1
                    fi
                else
                    success "$package installed successfully"
                fi
            done
        else
            success "All packages installed successfully"
        fi
        
        # Report failed packages
        if [ ${#failed_packages[@]} -gt 0 ]; then
            warn "The following packages failed to install: ${failed_packages[*]}"
            warn "You may need to install these manually later"
        fi
    else
        log "All packages are already installed"
    fi
}

# Function to backup existing configs
backup_configs() {
    log "Backing up existing configurations..."
    
    # Create backup directory with timestamp
    backup_dir="$HOME/.config/nibras-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup configurations if they exist
    if [ -d "$HOME/.config/hypr" ]; then
        mv "$HOME/.config/hypr" "$backup_dir/hypr-old"
        log "Backed up hypr config to $backup_dir/hypr-old"
    fi
    
    if [ -d "$HOME/.config/quickshell" ]; then
        mv "$HOME/.config/quickshell" "$backup_dir/quickshell-old"
        log "Backed up quickshell config to $backup_dir/quickshell-old"
    fi
    
    if [ -d "$HOME/.config/wofi" ]; then
        mv "$HOME/.config/wofi" "$backup_dir/wofi-old"
        log "Backed up wofi config to $backup_dir/wofi-old"
    fi
    
    if [ -d "$HOME/.config/easyeffects" ]; then
        mv "$HOME/.config/easyeffects" "$backup_dir/easyeffects-old"
        log "Backed up easyeffects config to $backup_dir/easyeffects-old"
    fi
    
    if [ -f "$HOME/.config/fish/config.fish" ]; then
        cp "$HOME/.config/fish/config.fish" "$backup_dir/config.fish.backup"
        log "Backed up fish config to $backup_dir/config.fish.backup"
    fi
    
    log "Backup completed in: $backup_dir"
}

# Function to setup Python environment and install packages
setup_python_env() {
    log "Setting up Python environment for image processing..."
    
    # Create virtual environment
    python -m venv "$HOME/.nibras-venv"
    
    # Activate virtual environment and install packages
    source "$HOME/.nibras-venv/bin/activate"
    pip install --upgrade pip
    pip install "rembg[gpu]" pillow
    deactivate
    
    log "Python environment setup completed"
}

# Function to extract themes
extract_themes() {
    log "Extracting GTK themes..."
    
    themes_dir="$HOME/.themes"
    mkdir -p "$themes_dir"
    
    if [ -d "$HOME/.config/hypr/config/gtk-themes" ]; then
        cp -r "$HOME/.config/hypr/config/gtk-themes/"* "$themes_dir/"
        log "GTK themes extracted to $themes_dir"
    else
        warn "GTK themes directory not found, skipping..."
    fi
}

# Function to setup directories and copy files
setup_config_files() {
    log "Setting up configuration files..."
    
    # Create necessary directories
    mkdir -p "$HOME/.local/share/color-schemes/"
    mkdir -p "$HOME/.local/share/konsole/"
    mkdir -p "$HOME/.config/Kvantum/"
    mkdir -p "$HOME/.config/qt5ct/"
    mkdir -p "$HOME/.config/qt6ct/"
    mkdir -p "$HOME/.fonts"
    mkdir -p "$HOME/.local/share/icons"
    
    # Copy configuration files
    if [ -d "$HOME/NibrasShell" ]; then
        config_source="$HOME/NibrasShell"
    else
        error "NibrasShell directory not found. Please clone the repository first."
    fi
    
    # Copy main configs
    cp -r "$config_source/"* "$HOME/.config/hypr/"
    cp -r "$HOME/.config/hypr/config/quickshell" "$HOME/.config/quickshell"
    cp -r "$HOME/.config/hypr/config/wofi" "$HOME/.config/wofi"
    cp "$HOME/.config/hypr/config/config.fish" "$HOME/.config/fish/config.fish"
    
    # Set script permissions
    chmod +x "$HOME/.config/hypr/scripts/"* 2>/dev/null || warn "Could not set permissions for hypr scripts"
    chmod +x "$HOME/.config/quickshell/scripts/"* 2>/dev/null || warn "Could not set permissions for quickshell scripts"
    
    # Copy easyeffects settings
    cp -r "$HOME/.config/hypr/config/easyeffects" "$HOME/.config/easyeffects"
    
    # Copy theme files
    cp -r "$HOME/.config/hypr/config/plasma-colors/"* "$HOME/.local/share/color-schemes/"
    cp -r "$HOME/.config/hypr/config/kvantum-themes/"* "$HOME/.config/Kvantum/"
    cp -r "$HOME/.config/hypr/config/konsole/"* "$HOME/.local/share/konsole/"
    cp "$HOME/.config/hypr/config/qt5ct.conf" "$HOME/.config/qt5ct/"
    cp "$HOME/.config/hypr/config/qt6ct.conf" "$HOME/.config/qt6ct/"
    
    # Copy fonts
    cp -r "$HOME/.config/hypr/config/.fonts/"* "$HOME/.fonts/"
    
    log "Configuration files copied successfully"
}

# Function to extract icon themes
extract_icons() {
    log "Extracting icon themes..."
    
    icons_dir="$HOME/.config/hypr/config/icons"
    target_dir="$HOME/.local/share/icons"
    
    if [ ! -d "$icons_dir" ]; then
        warn "Icons directory not found, skipping icon extraction..."
        return
    fi
    
    # Array of icon archives
    declare -a icon_archives=(
        "BeautySolar.tar.gz"
        "Delight-brown-dark.tar.gz"
        "Gradient-Dark-Icons.tar.gz"
        "Infinity-Dark-Icons.tar.gz"
        "la-capitaine-icon-theme.tar.gz"
        "Magma.tar.gz"
        "oomox-aesthetic-dark.tar.gz"
        "Vivid-Dark-Icons.tar.gz"
        "Windows11-red-dark.tar.gz"
        "Zafiro-Nord-Dark-Black.tar.gz"
    )
    
    for archive in "${icon_archives[@]}"; do
        if [ -f "$icons_dir/$archive" ]; then
            log "Extracting $archive..."
            tar xf "$icons_dir/$archive" -C "$target_dir"
        else
            warn "Icon archive $archive not found, skipping..."
        fi
    done
    
    log "Icon themes extraction completed"
}

# Main installation function
main() {
    log "Starting NibrasShell installation..."
    
    # Ask for confirmation
    echo -e "${BLUE}This script will install NibrasShell and modify your system configuration.${NC}"
    echo -e "${BLUE}Your existing configs will be backed up automatically.${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installation cancelled by user"
        exit 0
    fi
    
    # Authenticate sudo early and keep it alive
    log "Please authenticate for system-level operations..."
    if ! sudo -v; then
        error "Authentication failed. Cannot continue without sudo access."
        exit 1
    fi
    
    # Keep sudo alive in background
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    
    # Define package arrays - split problematic packages
    essential_packages_repo=(
        "base-devel" "brightnessctl" "network-manager-applet" "konsole" 
        "blueman" "ark" "dolphin" "ffmpegthumbs" "playerctl" "kvantum" 
        "polkit-kde-agent" "jq" "gufw" "tar" "gammastep" "wl-clipboard" 
        "easyeffects" "hyprpicker" "bc" "sysstat" "kitty" 
        "sassc" "systemsettings" "acpi" "fish" "plasma5support" 
        "plasma5-integration" "plasma-framework5" "ttf-jetbrains-mono-nerd" 
        "ttf-fantasque-nerd" "powerdevil" "power-profiles-daemon" 
        "libjpeg6-turbo" "swww" "python-regex" "copyq"
    )
    
    # Potentially problematic AUR packages
    aur_packages=(
        "hyprshot-git" "quickshell" "kde-material-you-colors"
    )
    
    optional_packages=(
        "orchis-theme-git" "visual-studio-code-bin" "nwg-look-bin" 
        "qt5ct" "strawberry"
    )
    
    # Install essential packages from official repos first
    log "Installing essential packages from official repositories..."
    install_packages "${essential_packages_repo[@]}"
    
    # Install AUR packages separately
    log "Installing AUR packages (may take longer)..."
    install_packages "${aur_packages[@]}"
    
    # Ask about optional packages
    echo -e "${BLUE}Do you want to install optional applications? (VS Code, Strawberry, etc.)${NC}"
    read -p "(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Installing optional packages..."
        install_packages "${optional_packages[@]}"
    fi
    
    # Setup Python environment
    setup_python_env
    
    # Clone NibrasShell repository
    if [ ! -d "$HOME/NibrasShell" ]; then
        log "Cloning NibrasShell repository..."
        git clone https://github.com/AhmedSaadi0/NibrasShell.git "$HOME/NibrasShell"
    else
        log "NibrasShell repository already exists"
    fi
    
    # Backup existing configs
    backup_configs
    
    # Setup configuration files
    setup_config_files
    
    # Extract themes and icons
    extract_themes
    extract_icons
    
    # Refresh font cache
    log "Refreshing font cache..."
    fc-cache -fv
    
    log "Installation completed successfully!"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}NibrasShell has been installed!${NC}"
    echo -e "${BLUE}You can now reboot or restart your Hyprland session.${NC}"
    echo -e "${BLUE}Note: You can change system fonts to 'JF Flat' for the complete experience.${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run main function
main "$@"
