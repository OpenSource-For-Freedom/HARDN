#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# Configure automatic security updates for Debian-based systems
configure_automatic_updates() {
    HARDN_STATUS "info" "Configuring automatic security updates for Debian-based systems..."
    
    # Source OS release information
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        HARDN_STATUS "info" "Detected OS: $PRETTY_NAME"
    else
        HARDN_STATUS "error" "Cannot detect OS information (/etc/os-release not found)"
        return 1
    fi
    
    # Install unattended-upgrades if not present
    if ! is_package_installed "unattended-upgrades"; then
        HARDN_STATUS "info" "Installing unattended-upgrades package..."
        if install_package "unattended-upgrades"; then
            HARDN_STATUS "pass" "unattended-upgrades installed successfully"
        else
            HARDN_STATUS "error" "Failed to install unattended-upgrades"
            return 1
        fi
    else
        HARDN_STATUS "pass" "unattended-upgrades is already installed"
    fi
    
    # Backup existing configuration
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        backup_file "/etc/apt/apt.conf.d/50unattended-upgrades"
    fi
    
    # Configure based on detected OS
    HARDN_STATUS "info" "Configuring unattended-upgrades for OS: $ID"
    
    case "${ID}" in
        "debian")
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
// HARDN Automatic Security Updates Configuration for Debian
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}:\${distro_codename}-updates";
};

Unattended-Upgrade::Package-Blacklist {
    // Add any packages you want to exclude from automatic updates
    // "linux-image-*";
    // "kernel*";
};

// Automatically remove unused kernel packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Remove dependencies that are no longer needed for the upgraded packages
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// Remove unused dependencies after the upgrade
Unattended-Upgrade::Remove-Unused-Dependencies "false";

// Automatically reboot WITHOUT CONFIRMATION after the upgrade
// if file /var/run/reboot-required is found
Unattended-Upgrade::Automatic-Reboot "false";

// Enable logging to syslog
Unattended-Upgrade::SyslogEnable "true";

// Remove all unused dependencies after the upgrade
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Split the upgrade into the smallest possible chunks
Unattended-Upgrade::MinimalSteps "true";

// Install security updates on shutdown
Unattended-Upgrade::InstallOnShutdown "false";

// Send email to this address for problems or packages upgrades
// Unattended-Upgrade::Mail "root";

// Set the maximum size of the dpkg journal
Unattended-Upgrade::MaxDpkgJournalSize "100";
EOF
            HARDN_STATUS "pass" "Debian automatic updates configured"
            ;;
            
        "ubuntu")
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
// HARDN Automatic Security Updates Configuration for Ubuntu
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
    "\${distro_id}:\${distro_codename}-updates";
};

Unattended-Upgrade::Package-Blacklist {
    // Add any packages you want to exclude from automatic updates
};

Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "false";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
EOF
            HARDN_STATUS "pass" "Ubuntu automatic updates configured"
            ;;
            
        *)
            # Generic Debian-based fallback
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
// HARDN Generic Automatic Security Updates Configuration
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};

Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
EOF
            HARDN_STATUS "warning" "Generic configuration applied for unsupported OS: $ID"
            ;;
    esac
    
    # Configure automatic update schedule
    HARDN_STATUS "info" "Configuring automatic update schedule..."
    
    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
// HARDN Automatic Updates Schedule
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    # Enable and start the service
    if enable_service "unattended-upgrades"; then
        HARDN_STATUS "pass" "unattended-upgrades service enabled"
    else
        HARDN_STATUS "warning" "Failed to enable unattended-upgrades service"
    fi
    
    # Verify configuration
    HARDN_STATUS "info" "Verifying automatic updates configuration..."
    
    if systemctl is-enabled unattended-upgrades >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Automatic updates service is enabled"
    else
        HARDN_STATUS "warning" "Automatic updates service is not enabled"
    fi
    
    # Test configuration
    HARDN_STATUS "info" "Testing unattended-upgrades configuration..."
    if unattended-upgrade --dry-run --debug 2>&1 | grep -q "Checking"; then
        HARDN_STATUS "pass" "Configuration test successful"
    else
        HARDN_STATUS "warning" "Configuration test had issues"
    fi
    
    HARDN_STATUS "pass" "Automatic security updates configuration completed"
}

main() {
    check_root
    
    HARDN_STATUS "info" "Starting automatic security updates configuration..."
    
    configure_automatic_updates
    
    HARDN_STATUS "pass" "Automatic security updates setup completed"
    log_tool_execution "auto_update.sh"
}

main "$@"