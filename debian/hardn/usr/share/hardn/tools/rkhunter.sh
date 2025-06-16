#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: rkhunter.sh
# Purpose: Install and configure RKHunter rootkit detection system
# Location: /src/tools/rkhunter.sh

check_root
log_tool_execution "rkhunter.sh"

enable_rkhunter() {
    HARDN_STATUS "info" "Installing RKHunter rootkit detection system..."
    
    # Install rkhunter package
    if ! is_package_installed rkhunter; then
        HARDN_STATUS "info" "Installing rkhunter package..."
        if install_package rkhunter; then
            HARDN_STATUS "pass" "RKHunter package installed successfully"
        else
            HARDN_STATUS "error" "RKHunter installation failed, skipping setup"
            return 1
        fi
    else
        HARDN_STATUS "pass" "RKHunter already installed"
    fi

    HARDN_STATUS "info" "Configuring RKHunter settings..."
    
    # Disable web command for security
    if sed -i 's|^WEB_CMD=.*|#WEB_CMD=|' /etc/rkhunter.conf; then
        HARDN_STATUS "pass" "Disabled WEB_CMD for security"
    else
        HARDN_STATUS "warning" "Could not disable WEB_CMD setting"
    fi

    # Configure mirrors mode
    if sed -i 's|^MIRRORS_MODE=.*|MIRRORS_MODE=1|' /etc/rkhunter.conf; then
        HARDN_STATUS "pass" "Configured mirrors mode"
    else
        HARDN_STATUS "warning" "Could not configure mirrors mode"
    fi

    # Set proper permissions on rkhunter directory
    if [ -d /var/lib/rkhunter ]; then
        chown -R root:root /var/lib/rkhunter
        chmod -R 755 /var/lib/rkhunter
        HARDN_STATUS "pass" "Set proper permissions on RKHunter directory"
    fi

    # Update RKHunter database
    HARDN_STATUS "info" "Updating RKHunter database..."
    if rkhunter --update --quiet; then
        HARDN_STATUS "pass" "RKHunter database updated successfully"
    else
        HARDN_STATUS "warning" "RKHunter update failed, skipping property update"
        return 0
    fi

    # Update properties database
    HARDN_STATUS "info" "Updating RKHunter properties database..."
    if rkhunter --propupd --quiet; then
        HARDN_STATUS "pass" "RKHunter properties updated successfully"
    else
        HARDN_STATUS "warning" "RKHunter properties update failed"
    fi

    HARDN_STATUS "pass" "RKHunter installation and configuration completed successfully"
}

main() {
    enable_rkhunter
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
