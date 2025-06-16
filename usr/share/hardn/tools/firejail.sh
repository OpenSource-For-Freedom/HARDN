#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: firejail.sh
# Purpose: Configure Firejail application sandboxing for security
# Location: /src/tools/firejail.sh

check_root
log_tool_execution "firejail.sh"

configure_firejail() {
    HARDN_STATUS "info" "Configuring Firejail for application sandboxing..."

    # Install firejail if not present
    if ! is_package_installed firejail; then
        HARDN_STATUS "info" "Installing Firejail..."
        if install_package firejail; then
            HARDN_STATUS "pass" "Firejail installed successfully"
        else
            HARDN_STATUS "error" "Failed to install Firejail"
            return 1
        fi
    else
        HARDN_STATUS "pass" "Firejail already installed"
    fi

    # Check if firejail command is available
    if ! command_exists firejail; then
        HARDN_STATUS "error" "Firejail command not found after installation"
        return 1
    fi

    HARDN_STATUS "pass" "Firejail is available and ready"

    # Configure Firefox sandboxing
    if command_exists firefox; then
        HARDN_STATUS "info" "Setting up Firejail sandbox for Firefox..."
        if ln -sf /usr/bin/firejail /usr/local/bin/firefox; then
            HARDN_STATUS "pass" "Firefox Firejail sandbox configured"
        else
            HARDN_STATUS "warning" "Failed to configure Firefox sandbox"
        fi
    else
        HARDN_STATUS "info" "Firefox not found, skipping sandbox setup"
    fi

    # Configure Chrome sandboxing
    local chrome_found=false
    for chrome_cmd in "google-chrome" "chromium" "chrome"; do
        if command_exists "$chrome_cmd"; then
            HARDN_STATUS "info" "Setting up Firejail sandbox for $chrome_cmd..."
            if ln -sf /usr/bin/firejail "/usr/local/bin/$chrome_cmd"; then
                HARDN_STATUS "pass" "$chrome_cmd Firejail sandbox configured"
                chrome_found=true
            else
                HARDN_STATUS "warning" "Failed to configure $chrome_cmd sandbox"
            fi
            break
        fi
    done
    
    if [ "$chrome_found" = false ]; then
        HARDN_STATUS "info" "Chrome/Chromium not found, skipping sandbox setup"
    fi

    # Configure additional applications
    local apps_to_sandbox=("thunderbird" "vlc" "evince" "libreoffice")
    
    HARDN_STATUS "info" "Configuring additional application sandboxes..."
    for app in "${apps_to_sandbox[@]}"; do
        if command_exists "$app"; then
            if ln -sf /usr/bin/firejail "/usr/local/bin/$app"; then
                HARDN_STATUS "pass" "$app sandbox configured"
            else
                HARDN_STATUS "warning" "Failed to configure $app sandbox"
            fi
        fi
    done

    # Create custom firejail profiles
    HARDN_STATUS "info" "Creating custom Firejail security profiles..."
    
    # Secure browser profile
    cat > /etc/firejail/browser-secure.profile << 'EOF'
# Secure browser profile for HARDN
include browser-common.inc
include disable-common.inc
include disable-devel.inc
include disable-interpreters.inc
include disable-programs.inc

caps.drop all
netfilter
noroot
protocol unix,inet,inet6
seccomp
shell none

private-dev
private-tmp
private-cache

blacklist /boot
blacklist /media
blacklist /mnt
blacklist /opt
blacklist /root
blacklist /run/user
blacklist /srv
blacklist /sys

read-only /etc
EOF

    HARDN_STATUS "pass" "Custom browser security profile created"

    # Test firejail functionality
    HARDN_STATUS "info" "Testing Firejail functionality..."
    if firejail --version >/dev/null 2>&1; then
        local version=$(firejail --version | head -n1)
        HARDN_STATUS "pass" "Firejail test successful: $version"
    else
        HARDN_STATUS "warning" "Firejail test failed"
    fi

    HARDN_STATUS "pass" "Firejail configuration completed successfully"
}

main() {
    configure_firejail
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
