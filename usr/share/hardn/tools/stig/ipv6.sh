#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG IPv6 Disable Configuration
# Implements DISA STIG requirements for IPv6 security when not required

configure_ipv6_disable() {
    HARDN_STATUS "INFO" "Configuring IPv6 disable per STIG requirements"
    
    local sysctl_conf="/etc/sysctl.d/99-hardn-ipv6.conf"
    
    # Backup existing sysctl configuration
    if [ -f "$sysctl_conf" ]; then
        backup_file "$sysctl_conf"
    fi
    
    # Create IPv6 disable configuration
    cat <<EOF > "$sysctl_conf"
# STIG IPv6 Security Configuration
# Disable IPv6 when not required for security compliance

# Disable IPv6 for all interfaces
net.ipv6.conf.all.disable_ipv6 = 1

# Disable IPv6 for default interface
net.ipv6.conf.default.disable_ipv6 = 1

# Disable IPv6 for loopback interface
net.ipv6.conf.lo.disable_ipv6 = 1

# Additional IPv6 security settings
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.autoconf = 0
net.ipv6.conf.default.autoconf = 0
EOF
    
    # Set proper permissions
    chmod 644 "$sysctl_conf"
    chown root:root "$sysctl_conf"
    
    HARDN_STATUS "INFO" "IPv6 disable configuration created"
    
    # Apply sysctl settings immediately
    HARDN_STATUS "INFO" "Applying IPv6 disable settings"
    if sysctl -p "$sysctl_conf"; then
        HARDN_STATUS "PASS" "IPv6 disable settings applied successfully"
    else
        HARDN_STATUS "ERROR" "Failed to apply IPv6 disable settings"
        return 1
    fi
    
    # Disable IPv6 in GRUB configuration
    HARDN_STATUS "INFO" "Configuring GRUB to disable IPv6"
    local grub_default="/etc/default/grub"
    
    if [ -f "$grub_default" ]; then
        backup_file "$grub_default"
        
        # Add IPv6 disable to GRUB command line
        if grep -q "ipv6.disable=1" "$grub_default"; then
            HARDN_STATUS "INFO" "IPv6 already disabled in GRUB configuration"
        else
            # Add ipv6.disable=1 to GRUB_CMDLINE_LINUX_DEFAULT
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' "$grub_default"
            
            # Update GRUB configuration
            if update-grub; then
                HARDN_STATUS "PASS" "GRUB configuration updated to disable IPv6"
            else
                HARDN_STATUS "WARNING" "Failed to update GRUB configuration"
            fi
        fi
    else
        HARDN_STATUS "WARNING" "GRUB configuration file not found"
    fi
    
    # Create IPv6 blacklist for modprobe
    local modprobe_conf="/etc/modprobe.d/hardn-ipv6-blacklist.conf"
    
    cat <<EOF > "$modprobe_conf"
# STIG IPv6 Module Blacklist
# Prevent IPv6 modules from loading
blacklist ipv6
EOF
    
    chmod 644 "$modprobe_conf"
    chown root:root "$modprobe_conf"
    
    HARDN_STATUS "INFO" "IPv6 module blacklist configured"
    
    # Verify current IPv6 status
    HARDN_STATUS "INFO" "Verifying IPv6 disable status"
    if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]; then
        local ipv6_disabled
        ipv6_disabled=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
        if [ "$ipv6_disabled" = "1" ]; then
            HARDN_STATUS "PASS" "IPv6 is currently disabled"
        else
            HARDN_STATUS "WARNING" "IPv6 is still enabled (reboot may be required)"
        fi
    else
        HARDN_STATUS "WARNING" "IPv6 status cannot be determined"
    fi
    
    HARDN_STATUS "PASS" "IPv6 disable configuration completed"
}

main() {
    check_root
    log_tool_execution "ipv6.sh" "STIG IPv6 disable configuration"
    
    HARDN_STATUS "INFO" "Starting STIG IPv6 disable configuration"
    
    configure_ipv6_disable
    
    HARDN_STATUS "PASS" "STIG IPv6 disable configuration completed successfully"
    HARDN_STATUS "WARNING" "System reboot recommended to fully apply IPv6 disable settings"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi