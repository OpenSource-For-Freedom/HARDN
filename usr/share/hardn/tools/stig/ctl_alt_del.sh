#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG Ctrl-Alt-Del Security Configuration
# Implements DISA STIG requirements for secure key sequence handling

configure_ctrl_alt_del_security() {
    HARDN_STATUS "INFO" "Configuring Ctrl-Alt-Del security per STIG requirements"
    
    # Mask the ctrl-alt-del target to prevent unauthorized reboot
    HARDN_STATUS "INFO" "Disabling Ctrl-Alt-Del reboot functionality"
    if systemctl mask ctrl-alt-del.target; then
        HARDN_STATUS "PASS" "Ctrl-Alt-Del target masked successfully"
    else
        HARDN_STATUS "ERROR" "Failed to mask Ctrl-Alt-Del target"
        return 1
    fi
    
    # Reload systemd to apply changes
    HARDN_STATUS "INFO" "Reloading systemd configuration"
    if systemctl daemon-reload; then
        HARDN_STATUS "PASS" "Systemd configuration reloaded"
    else
        HARDN_STATUS "WARNING" "Failed to reload systemd configuration"
    fi
    
    # Additional security: disable console key sequences
    HARDN_STATUS "INFO" "Configuring console key sequence security"
    local sysctl_conf="/etc/sysctl.d/99-hardn-console.conf"
    
    if [ -f "$sysctl_conf" ]; then
        backup_file "$sysctl_conf"
    fi
    
    cat <<EOF > "$sysctl_conf"
# STIG Console Security Configuration
# Disable dangerous console key sequences

# Disable Ctrl-Alt-Del at kernel level
kernel.ctrl-alt-del = 0

# Disable magic SysRq key combinations
kernel.sysrq = 0

# Additional console security
kernel.printk = 3 4 1 3
kernel.dmesg_restrict = 1
EOF
    
    chmod 644 "$sysctl_conf"
    chown root:root "$sysctl_conf"
    
    # Apply sysctl settings
    HARDN_STATUS "INFO" "Applying console security settings"
    if sysctl -p "$sysctl_conf"; then
        HARDN_STATUS "PASS" "Console security settings applied"
    else
        HARDN_STATUS "WARNING" "Some console security settings may not have been applied"
    fi
    
    # Configure getty to prevent Ctrl-Alt-Del
    HARDN_STATUS "INFO" "Configuring getty security settings"
    local getty_override_dir="/etc/systemd/system/getty@.service.d"
    local getty_override="$getty_override_dir/hardn-security.conf"
    
    mkdir -p "$getty_override_dir"
    cat <<EOF > "$getty_override"
# STIG Getty Security Configuration
[Service]
# Prevent unauthorized access via console
ExecStart=
ExecStart=-/sbin/agetty --noclear --keep-baud %I 115200,38400,9600 \$TERM
TTYVTDisallocate=yes

# Security settings
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
EOF
    
    chmod 644 "$getty_override"
    chown root:root "$getty_override"
    
    # Reload systemd to apply getty changes
    if systemctl daemon-reload; then
        HARDN_STATUS "PASS" "Getty security configuration applied"
    else
        HARDN_STATUS "WARNING" "Failed to apply getty security configuration"
    fi
    
    # Verify Ctrl-Alt-Del is disabled
    HARDN_STATUS "INFO" "Verifying Ctrl-Alt-Del configuration"
    if systemctl is-masked ctrl-alt-del.target >/dev/null 2>&1; then
        HARDN_STATUS "PASS" "Ctrl-Alt-Del target is properly masked"
    else
        HARDN_STATUS "ERROR" "Ctrl-Alt-Del target is not masked"
        return 1
    fi
    
    # Check sysctl settings
    local ctrl_alt_del_setting
    ctrl_alt_del_setting=$(sysctl -n kernel.ctrl-alt-del 2>/dev/null)
    if [ "$ctrl_alt_del_setting" = "0" ]; then
        HARDN_STATUS "PASS" "Kernel Ctrl-Alt-Del is properly disabled"
    else
        HARDN_STATUS "WARNING" "Kernel Ctrl-Alt-Del setting: $ctrl_alt_del_setting"
    fi
    
    local sysrq_setting
    sysrq_setting=$(sysctl -n kernel.sysrq 2>/dev/null)
    if [ "$sysrq_setting" = "0" ]; then
        HARDN_STATUS "PASS" "Magic SysRq keys are properly disabled"
    else
        HARDN_STATUS "WARNING" "Magic SysRq setting: $sysrq_setting"
    fi
    
    HARDN_STATUS "PASS" "Ctrl-Alt-Del security configuration completed"
}

main() {
    check_root
    log_tool_execution "ctl_alt_del.sh" "STIG Ctrl-Alt-Del security configuration"
    
    HARDN_STATUS "INFO" "Starting STIG Ctrl-Alt-Del security configuration"
    
    configure_ctrl_alt_del_security
    
    HARDN_STATUS "PASS" "STIG Ctrl-Alt-Del security configuration completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
