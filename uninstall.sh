#!/bin/bash

# NibrasShell Uninstaller Script
# Removes NibrasShell configuration and optionally uninstalls packages

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root"
   exit 1
fi

# Function to find backup directories
find_backups() {
    find "$HOME/.config" -maxdepth 1 -type d -name "nibras-backup-*" 2>/dev/null | sort -r
}

# Function to list available backups
list_backups() {
    local backups=($(find_backups))
    
    if [ ${#backups[@]} -eq 0 ]; then
        warn "No NibrasShell backups found"
        return 1
    fi
    
    echo -e "${BLUE}Available backups:${NC}"
    for i in "${!backups[@]}"; do
        local backup_name=$(basename "${backups[$i]}")
        local backup_date=$(echo "$backup_name" | sed 's/nibras-backup-//' | sed 's/-/ /')
        echo "  $((i+1)). $backup_date (${backups[$i]})"
    done
    
    return 0
}

# Function to restore from backup
restore_from_backup() {
    local backups=($(find_backups))
    
    if ! list_backups; then
        return 1
    fi
    
    echo
    read -p "Select backup to restore (number, or 0 to skip): " backup_choice
    
    if [[ "$backup_choice" =~ ^[1-9][0-9]*$ ]] && [ "$backup_choice" -le "${#backups[@]}" ]; then
        local selected_backup="${backups[$((backup_choice-1))]}"
        log "Restoring from backup: $selected_backup"
        
        # Remove current configs
        rm -rf "$HOME/.config/hypr" 2>/dev/null || true
        rm -rf "$HOME/.config/quickshell" 2>/dev/null || true
        rm -rf "$HOME/.config/wofi" 2>/dev/null || true
        rm -rf "$HOME/.config/easyeffects" 2>/dev/null || true
        
        # Restore from backup
        [ -d "$selected_backup/hypr-old" ] && mv "$selected_backup/hypr-old" "$HOME/.config/hypr"
        [ -d "$selected_backup/quickshell-old" ] && mv "$selected_backup/quickshell-old" "$HOME/.config/quickshell"
        [ -d "$selected_backup/wofi-old" ] && mv "$selected_backup/wofi-old" "$HOME/.config/wofi"
        [ -d "$selected_backup/easyeffects-old" ] && mv "$selected_backup/easyeffects-old" "$HOME/.config/easyeffects"
        [ -f "$selected_backup/config.fish.backup" ] && cp "$selected_backup/config.fish.backup" "$HOME/.config/fish/config.fish"
        
        success "Configuration restored from backup"
        
        # Ask if user wants to remove the backup directory
        read -p "Remove this backup directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$selected_backup"
            log "Backup directory removed"
        fi
    elif [ "$backup_choice" = "0" ]; then
        log "Skipping backup restoration"
    else
        warn "Invalid selection, skipping backup restoration"
    fi
}

# Function to remove configuration files
remove_configs() {
    log "Removing NibrasShell configuration files..."
    
    # Remove main configuration directories
    rm -rf "$HOME/.config/hypr" 2>/dev/null || true
    rm -rf "$HOME/.config/quickshell" 2>/dev/null || true
    rm -rf "$HOME/.config/wofi" 2>/dev/null || true
    rm -rf "$HOME/.config/easyeffects" 2>/dev/null || true
    
    # Remove theme and icon configurations
    log "Removing theme configurations..."
    rm -rf "$HOME/.local/share/color-schemes" 2>/dev/null || true
    rm -rf "$HOME/.local/share/konsole" 2>/dev/null || true
    rm -rf "$HOME/.config/Kvantum" 2>/dev/null || true
    rm -f "$HOME/.config/qt5ct/qt5ct.conf" 2>/dev/null || true
    rm -f "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null || true
    
    # Remove fonts (ask user first)
    if [ -d "$HOME/.fonts" ] && [ "$(ls -A $HOME/.fonts)" ]; then
        read -p "Remove custom fonts from ~/.fonts? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.fonts"/*
            log "Custom fonts removed"
        fi
    fi
    
    # Remove GTK themes
    if [ -d "$HOME/.themes" ] && [ "$(ls -A $HOME/.themes)" ]; then
        read -p "Remove GTK themes from ~/.themes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.themes"
            log "GTK themes removed"
        fi
    fi
    
    # Remove icon themes (ask user first)
    if [ -d "$HOME/.local/share/icons" ] && [ "$(ls -A $HOME/.local/share/icons)" ]; then
        echo -e "${BLUE}Icon themes to remove:${NC}"
        ls "$HOME/.local/share/icons" | grep -E "(BeautySolar|Delight-brown-dark|Gradient-Dark-Icons|Infinity-Dark-Icons|la-capitaine|Magma|oomox-aesthetic-dark|Vivid-Dark-Icons|Windows11-red-dark|Zafiro-Nord-Dark-Black)" 2>/dev/null || echo "None found"
        
        read -p "Remove NibrasShell icon themes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$HOME/.local/share/icons" 2>/dev/null || return
            rm -rf BeautySolar* Delight-brown-dark* Gradient-Dark-Icons* \
                   Infinity-Dark-Icons* la-capitaine* Magma* oomox-aesthetic-dark* \
                   Vivid-Dark-Icons* Windows11-red-dark* Zafiro-Nord-Dark-Black* 2>/dev/null || true
            log "Icon themes removed"
        fi
    fi
    
    success "Configuration files removed"
}

# Function to remove Python environment
remove_python_env() {
    if [ -d "$HOME/.nibras-venv" ]; then
        log "Removing Python virtual environment..."
        rm -rf "$HOME/.nibras-venv"
        success "Python environment removed"
    fi
}

# Function to remove NibrasShell repository
remove_repository() {
    if [ -d "$HOME/NibrasShell" ]; then
        read -p "Remove NibrasShell repository from ~/NibrasShell? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/NibrasShell"
            success "Repository removed"
        fi
    fi
}

# Function to uninstall packages
uninstall_packages() {
    echo -e "${BLUE}Package removal options:${NC}"
    echo "1. Remove NibrasShell-specific packages only"
    echo "2. Remove all packages (including system packages)"
    echo "3. Skip package removal"
    
    read -p "Choose option (1-3): " package_choice
    
    case $package_choice in
        1)
            log "Removing NibrasShell-specific packages..."
            local nibras_packages=(
                "hyprshot-git" "quickshell" "orchis-theme-git" 
                "visual-studio-code-bin" "nwg-look-bin" "strawberry"
                "kde-material-you-colors"
            )
            
            for package in "${nibras_packages[@]}"; do
                if yay -Qi "$package" &>/dev/null; then
                    log "Removing $package..."
                    yay -Rns "$package" --noconfirm 2>/dev/null || warn "Failed to remove $package"
                fi
            done
            success "NibrasShell-specific packages removed"
            ;;
            
        2)
            warn "This will remove ALL packages installed by NibrasShell!"
            read -p "Are you sure? This may break your system! (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                local all_packages=(
                    "brightnessctl" "network-manager-applet" "konsole" "blueman" 
                    "ark" "dolphin" "ffmpegthumbs" "playerctl" "kvantum" 
                    "polkit-kde-agent" "jq" "gufw" "gammastep" "wl-clipboard" 
                    "easyeffects" "hyprpicker" "hyprshot-git" "bc" "sysstat" 
                    "kitty" "sassc" "systemsettings" "acpi" "fish" 
                    "kde-material-you-colors" "plasma5support" "plasma5-integration" 
                    "plasma-framework5" "ttf-jetbrains-mono-nerd" "ttf-fantasque-nerd" 
                    "powerdevil" "power-profiles-daemon" "libjpeg6-turbo" "swww" 
                    "python-regex" "copyq" "quickshell" "orchis-theme-git" 
                    "visual-studio-code-bin" "nwg-look-bin" "qt5ct" "strawberry"
                )
                
                log "Removing all NibrasShell packages..."
                for package in "${all_packages[@]}"; do
                    if yay -Qi "$package" &>/dev/null; then
                        yay -Rns "$package" --noconfirm 2>/dev/null || warn "Failed to remove $package"
                    fi
                done
                success "All packages removed"
            else
                log "Package removal cancelled"
            fi
            ;;
            
        3)
            log "Skipping package removal"
            ;;
            
        *)
            warn "Invalid choice, skipping package removal"
            ;;
    esac
}

# Function to clean up backup directories
cleanup_backups() {
    local backups=($(find_backups))
    
    if [ ${#backups[@]} -gt 0 ]; then
        echo -e "${BLUE}Found ${#backups[@]} backup directories${NC}"
        read -p "Remove all backup directories? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for backup in "${backups[@]}"; do
                rm -rf "$backup"
                log "Removed backup: $(basename "$backup")"
            done
            success "All backups cleaned up"
        fi
    fi
}

# Function to refresh system
refresh_system() {
    log "Refreshing system caches..."
    
    # Refresh font cache
    fc-cache -fv >/dev/null 2>&1
    
    # Update desktop database
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    
    # Update icon cache
    gtk-update-icon-cache ~/.local/share/icons/ 2>/dev/null || true
    
    success "System caches refreshed"
}

# Main uninstall function
main() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}                    NibrasShell Uninstaller${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${YELLOW}This will remove NibrasShell configuration and optionally uninstall packages.${NC}"
    echo -e "${YELLOW}You can choose to restore from backup or completely remove everything.${NC}"
    echo
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Uninstallation cancelled by user"
        exit 0
    fi
    
    echo -e "${BLUE}Choose uninstall method:${NC}"
    echo "1. Restore from backup (recommended)"
    echo "2. Complete removal (remove everything)"
    echo "3. Custom removal (choose what to remove)"
    echo
    
    read -p "Select option (1-3): " uninstall_method
    
    case $uninstall_method in
        1)
            log "Starting restoration from backup..."
            if restore_from_backup; then
                refresh_system
                success "System restored from backup!"
            else
                error "No backups available for restoration"
            fi
            ;;
            
        2)
            log "Starting complete removal..."
            remove_configs
            remove_python_env
            remove_repository
            uninstall_packages
            cleanup_backups
            refresh_system
            success "Complete removal finished!"
            ;;
            
        3)
            log "Starting custom removal..."
            
            echo -e "${BLUE}What would you like to remove?${NC}"
            
            read -p "Remove configuration files? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # First try to restore from backup
                if list_backups >/dev/null 2>&1; then
                    read -p "Restore from backup instead of removing? (Y/n): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                        restore_from_backup
                    else
                        remove_configs
                    fi
                else
                    remove_configs
                fi
            fi
            
            read -p "Remove Python environment? (y/N): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && remove_python_env
            
            read -p "Remove repository? (y/N): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && remove_repository
            
            read -p "Remove packages? (y/N): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && uninstall_packages
            
            read -p "Clean up backup directories? (y/N): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && cleanup_backups
            
            refresh_system
            success "Custom removal completed!"
            ;;
            
        *)
            error "Invalid option selected"
            ;;
    esac
    
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}NibrasShell uninstallation completed!${NC}"
    echo -e "${BLUE}You may want to reboot or restart your session.${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run main function
main "$@"
