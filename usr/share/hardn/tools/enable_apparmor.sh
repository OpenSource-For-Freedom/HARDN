#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: enable_apparmor.sh
# Purpose: Enable and configure AppArmor mandatory access control
# Location: /src/tools/enable_apparmor.sh

check_root
log_tool_execution "enable_apparmor.sh"

enable_apparmor() {
    HARDN_STATUS "info" "Enabling and configuring AppArmor..."
    
    # Install AppArmor packages
    local apparmor_packages=("apparmor" "apparmor-utils" "apparmor-profiles")
    
    for pkg in "${apparmor_packages[@]}"; do
        if ! is_package_installed "$pkg"; then
            HARDN_STATUS "info" "Installing $pkg..."
            if install_package "$pkg"; then
                HARDN_STATUS "pass" "$pkg installed successfully"
            else
                HARDN_STATUS "error" "Failed to install $pkg"
                return 1
            fi
        else
            HARDN_STATUS "pass" "$pkg already installed"
        fi
    done
    
    # Enable and start AppArmor service
    if enable_service apparmor; then
        HARDN_STATUS "pass" "AppArmor service enabled and started"
    else
        HARDN_STATUS "error" "Failed to enable AppArmor service"
        return 1
    fi
    
    # Check AppArmor status
    HARDN_STATUS "info" "Checking AppArmor status..."
    if aa-status >/dev/null 2>&1; then
        local profiles_loaded=$(aa-status 2>/dev/null | grep "profiles are loaded" | awk '{print $1}')
        local profiles_enforcing=$(aa-status 2>/dev/null | grep "profiles are in enforce mode" | awk '{print $1}')
        
        HARDN_STATUS "pass" "AppArmor is active with $profiles_loaded profiles loaded"
        HARDN_STATUS "pass" "$profiles_enforcing profiles in enforce mode"
        
        # Enable additional profiles
        HARDN_STATUS "info" "Enabling additional security profiles..."
        
        # List of profiles to enable
        local profiles_to_enable=(
            "/usr/bin/firefox"
            "/usr/bin/thunderbird" 
            "/usr/bin/evince"
            "/usr/bin/libreoffice*"
        )
        
        for profile in "${profiles_to_enable[@]}"; do
            if [ -f "/etc/apparmor.d/$profile" ]; then
                if aa-enforce "$profile" 2>/dev/null; then
                    HARDN_STATUS "pass" "Enabled profile: $profile"
                else
                    HARDN_STATUS "warning" "Could not enable profile: $profile"
                fi
            fi
        done
    else
        HARDN_STATUS "error" "AppArmor is not functioning properly"
        return 1
    fi
    
    HARDN_STATUS "pass" "AppArmor configuration completed successfully"
}

main() {
    enable_apparmor
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi