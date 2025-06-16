#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: update_system_packages.sh
# Purpose: Update system packages securely
# Location: /src/tools/update_system_packages.sh

check_root
log_tool_execution "update_system_packages.sh"

update_system_packages() {
    HARDN_STATUS "info" "Starting system package updates..."
    
    # Update package lists
    HARDN_STATUS "info" "Updating package lists..."
    if apt update; then
        HARDN_STATUS "pass" "Package lists updated successfully"
    else
        HARDN_STATUS "error" "Failed to update package lists"
        return 1
    fi
    
    # Upgrade packages
    HARDN_STATUS "info" "Upgrading installed packages..."
    if DEBIAN_FRONTEND=noninteractive apt upgrade -y; then
        HARDN_STATUS "pass" "Packages upgraded successfully"
    else
        HARDN_STATUS "warning" "Some packages failed to upgrade"
    fi
    
    # Fix broken packages
    HARDN_STATUS "info" "Fixing broken package dependencies..."
    if apt --fix-broken install -y; then
        HARDN_STATUS "pass" "Broken package dependencies fixed"
    else
        HARDN_STATUS "warning" "Some broken dependencies could not be fixed"
    fi
    
    # Update security packages specifically
    HARDN_STATUS "info" "Updating security-related packages..."
    local security_packages=(
        "openssh-server" "openssh-client" "fail2ban" "ufw" 
        "apparmor" "auditd" "aide" "rkhunter" "lynis"
    )
    
    for pkg in "${security_packages[@]}"; do
        if is_package_installed "$pkg"; then
            HARDN_STATUS "info" "Updating $pkg..."
            if apt install --only-upgrade "$pkg" -y; then
                HARDN_STATUS "pass" "Updated $pkg successfully"
            else
                HARDN_STATUS "warning" "Failed to update $pkg"
            fi
        fi
    done
    
    # Clean up
    HARDN_STATUS "info" "Cleaning up package cache..."
    apt autoremove -y && apt autoclean
    HARDN_STATUS "pass" "Package cache cleaned"
    
    HARDN_STATUS "pass" "System package updates completed successfully"
}

main() {
    update_system_packages
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi