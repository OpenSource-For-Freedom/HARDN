#!/bin/bash

# HARDN Common Functions
# This file provides common functions used across HARDN security tools

# Colors for status output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# HARDN status function for consistent logging and output
# Usage: HARDN_STATUS "level" "message"
# Levels: info, pass, warning, error
HARDN_STATUS() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="/var/log/hardn/hardn-tools.log"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    
    case "$level" in
        "info")
            printf "${BLUE}[INFO]${NC} %s\n" "$message"
            echo "[$timestamp] [INFO] $message" >> "$log_file" 2>/dev/null || true
            ;;
        "pass")
            printf "${GREEN}[PASS]${NC} %s\n" "$message"
            echo "[$timestamp] [PASS] $message" >> "$log_file" 2>/dev/null || true
            ;;
        "warning")
            printf "${YELLOW}[WARNING]${NC} %s\n" "$message"
            echo "[$timestamp] [WARNING] $message" >> "$log_file" 2>/dev/null || true
            ;;
        "error")
            printf "${RED}[ERROR]${NC} %s\n" "$message"
            echo "[$timestamp] [ERROR] $message" >> "$log_file" 2>/dev/null || true
            ;;
        *)
            printf "${WHITE}[UNKNOWN]${NC} %s\n" "$message"
            echo "[$timestamp] [UNKNOWN] $message" >> "$log_file" 2>/dev/null || true
            ;;
    esac
}

# Additional helper functions for HARDN tools

# Check if a package is installed
is_package_installed() {
    local package="$1"
    dpkg -s "$package" >/dev/null 2>&1
}

# Check if a service is active
is_service_active() {
    local service="$1"
    systemctl is-active --quiet "$service" 2>/dev/null
}

# Check if a service exists
service_exists() {
    local service="$1"
    systemctl list-unit-files --type=service | grep -q "^${service}\.service"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        HARDN_STATUS "error" "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Create backup of a file
backup_file() {
    local file="$1"
    local backup_suffix="${2:-$(date +%Y%m%d_%H%M%S)}"
    
    if [[ -f "$file" ]]; then
        local backup_file="${file}.bak.${backup_suffix}"
        if cp "$file" "$backup_file"; then
            HARDN_STATUS "info" "Backed up $file to $backup_file"
            return 0
        else
            HARDN_STATUS "warning" "Failed to backup $file"
            return 1
        fi
    else
        HARDN_STATUS "warning" "File $file does not exist, no backup needed"
        return 1
    fi
}

# Install package with error handling
install_package() {
    local package="$1"
    
    if is_package_installed "$package"; then
        HARDN_STATUS "pass" "$package is already installed"
        return 0
    fi
    
    HARDN_STATUS "info" "Installing $package..."
    if apt-get update >/dev/null 2>&1 && apt-get install -y "$package"; then
        HARDN_STATUS "pass" "$package installed successfully"
        return 0
    else
        HARDN_STATUS "error" "Failed to install $package"
        return 1
    fi
}

# Enable and start a service
enable_service() {
    local service="$1"
    
    if ! service_exists "$service"; then
        HARDN_STATUS "warning" "Service $service does not exist"
        return 1
    fi
    
    if is_service_active "$service"; then
        HARDN_STATUS "pass" "$service is already active"
        return 0
    fi
    
    HARDN_STATUS "info" "Enabling and starting $service..."
    if systemctl enable --now "$service" >/dev/null 2>&1; then
        HARDN_STATUS "pass" "$service enabled and started successfully"
        return 0
    else
        HARDN_STATUS "error" "Failed to enable/start $service"
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Log execution completion
log_tool_execution() {
    local tool_name="$1"
    local log_file="/var/log/hardn/hardn-tools.log"
    
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    printf "[HARDN] %s executed at %s\n" "$tool_name" "$(date)" | tee -a "$log_file" 2>/dev/null || true
}

# Export functions so they're available to sourcing scripts
export -f HARDN_STATUS
export -f is_package_installed
export -f is_service_active
export -f service_exists
export -f check_root
export -f backup_file
export -f install_package
export -f enable_service
export -f command_exists
export -f log_tool_execution
