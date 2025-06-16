#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: firmware.sh
# Purpose: Install firmware updates and security patches
# Location: /src/tools/firmware.sh

check_root
log_tool_execution "firmware.sh"

install_firmware_updates() {
    HARDN_STATUS "info" "Checking for firmware updates..."
    
    # Install fwupd if not present
    if ! is_package_installed fwupd; then
        HARDN_STATUS "info" "Installing fwupd firmware update daemon..."
        if install_package fwupd; then
            HARDN_STATUS "pass" "fwupd installed successfully"
        else
            HARDN_STATUS "error" "Failed to install fwupd"
            return 1
        fi
    else
        HARDN_STATUS "pass" "fwupd already installed"
    fi
    
    # Refresh firmware metadata
    HARDN_STATUS "info" "Refreshing firmware metadata..."
    if fwupdmgr refresh 2>/dev/null; then
        HARDN_STATUS "pass" "Firmware metadata refreshed successfully"
    else
        HARDN_STATUS "warning" "Failed to refresh firmware metadata (may be normal in virtual environments)"
    fi
    
    # Check for available updates
    HARDN_STATUS "info" "Checking for available firmware updates..."
    if fwupdmgr get-updates 2>/dev/null; then
        HARDN_STATUS "info" "Found firmware updates - attempting to install..."
        
        # Apply firmware updates
        if fwupdmgr update --no-reboot-check 2>/dev/null; then
            HARDN_STATUS "pass" "Firmware updates applied successfully"
        else
            HARDN_STATUS "warning" "Firmware update process completed with warnings"
        fi
    else
        HARDN_STATUS "pass" "No firmware updates available or system not supported"
    fi
    
    # Update package lists
    HARDN_STATUS "info" "Updating system package lists..."
    if apt update -y >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Package lists updated successfully"
    else
        HARDN_STATUS "warning" "Package list update completed with warnings"
    fi
    
    HARDN_STATUS "pass" "Firmware update process completed"
}

main() {
    install_firmware_updates
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
