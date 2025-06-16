#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG Core Dump Security Configuration
# Implements DISA STIG requirements for core dump security

configure_core_dump_security() {
    HARDN_STATUS "INFO" "Configuring core dump security per STIG requirements"
    
    # Configure core dump limits
    HARDN_STATUS "INFO" "Setting core dump limits"
    local limits_conf="/etc/security/limits.conf"
    
    if [ -f "$limits_conf" ]; then
        backup_file "$limits_conf"
    fi
    
    # Add core dump limits if not already present
    if ! grep -q "hard core 0" "$limits_conf"; then
        echo "# STIG Core Dump Security - Disable core dumps" >> "$limits_conf"
        echo "* hard core 0" >> "$limits_conf"
        echo "* soft core 0" >> "$limits_conf"
        HARDN_STATUS "PASS" "Core dump limits configured in limits.conf"
    else
        HARDN_STATUS "INFO" "Core dump limits already configured in limits.conf"
    fi
    
    # Configure sysctl settings for core dumps
    HARDN_STATUS "INFO" "Configuring sysctl core dump settings"
    local sysctl_conf="/etc/sysctl.d/99-hardn-coredump.conf"
    
    if [ -f "$sysctl_conf" ]; then
        backup_file "$sysctl_conf"
    fi
    
    cat <<EOF > "$sysctl_conf"
# STIG Core Dump Security Configuration
# Disable core dumps for security compliance

# Disable core dumps for setuid programs
fs.suid_dumpable = 0

# Set core pattern to prevent core dumps
kernel.core_pattern = /dev/null

# Disable core dumps via pipe
kernel.core_uses_pid = 0

# Additional security settings related to core dumps
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
EOF
    
    chmod 644 "$sysctl_conf"
    chown root:root "$sysctl_conf"
    
    # Apply sysctl settings immediately
    HARDN_STATUS "INFO" "Applying core dump security settings"
    if sysctl -w fs.suid_dumpable=0; then
        HARDN_STATUS "PASS" "Core dump sysctl settings applied"
    else
        HARDN_STATUS "ERROR" "Failed to apply core dump sysctl settings"
        return 1
    fi
    
    # Apply all settings from configuration file
    if sysctl -p "$sysctl_conf"; then
        HARDN_STATUS "PASS" "All core dump security settings applied"
    else
        HARDN_STATUS "WARNING" "Some core dump security settings may not have been applied"
    fi
    
    # Configure systemd core dump handling
    HARDN_STATUS "INFO" "Configuring systemd core dump handling"
    local systemd_conf="/etc/systemd/coredump.conf"
    
    if [ -f "$systemd_conf" ]; then
        backup_file "$systemd_conf"
    fi
    
    # Create systemd core dump configuration
    mkdir -p /etc/systemd
    cat <<EOF > "$systemd_conf"
# STIG Systemd Core Dump Configuration
[Coredump]
# Disable core dump storage
Storage=none
# Disable core dump processing
ProcessSizeMax=0
# Disable external core dump processing
ExternalSizeMax=0
# Disable journald core dump logging
JournalSizeMax=0
EOF
    
    chmod 644 "$systemd_conf"
    chown root:root "$systemd_conf"
    
    # Restart systemd services to apply changes
    if systemctl daemon-reload; then
        HARDN_STATUS "PASS" "Systemd core dump configuration applied"
    else
        HARDN_STATUS "WARNING" "Failed to reload systemd configuration"
    fi
    
    # Disable apport (Ubuntu crash reporting) if present
    if command -v apport-cli >/dev/null 2>&1; then
        HARDN_STATUS "INFO" "Disabling Apport crash reporting"
        local apport_conf="/etc/default/apport"
        
        if [ -f "$apport_conf" ]; then
            backup_file "$apport_conf"
            sed -i 's/enabled=1/enabled=0/g' "$apport_conf"
            HARDN_STATUS "PASS" "Apport crash reporting disabled"
        fi
        
        # Stop apport service if running
        if systemctl is-active --quiet apport; then
            systemctl stop apport
            systemctl disable apport
            HARDN_STATUS "PASS" "Apport service stopped and disabled"
        fi
    fi
    
    # Verify core dump configuration
    HARDN_STATUS "INFO" "Verifying core dump security configuration"
    local suid_dumpable
    suid_dumpable=$(sysctl -n fs.suid_dumpable 2>/dev/null)
    
    if [ "$suid_dumpable" = "0" ]; then
        HARDN_STATUS "PASS" "Core dumps are properly disabled for setuid programs"
    else
        HARDN_STATUS "WARNING" "Core dumps may still be enabled: fs.suid_dumpable=$suid_dumpable"
    fi
    
    # Check ulimit core setting
    local core_limit
    core_limit=$(ulimit -c)
    if [ "$core_limit" = "0" ]; then
        HARDN_STATUS "PASS" "Core dump size limit is properly set to 0"
    else
        HARDN_STATUS "WARNING" "Core dump size limit is: $core_limit"
    fi
    
    HARDN_STATUS "PASS" "Core dump security configuration completed"
}

main() {
    check_root
    log_tool_execution "core_dumps.sh" "STIG core dump security configuration"
    
    HARDN_STATUS "INFO" "Starting STIG core dump security configuration"
    
    configure_core_dump_security
    
    HARDN_STATUS "PASS" "STIG core dump security configuration completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
