#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"

# HARDN SELinux Configuration
# Implements Security-Enhanced Linux with AppArmor conflict resolution

main() {
    check_root
    log_tool_execution "selinux.sh" "SELinux mandatory access control configuration"
    
    HARDN_STATUS "INFO" "Starting SELinux configuration with AppArmor conflict resolution"

    
    # Step 1: Disable AppArmor to prevent conflicts
    disable_apparmor
    
    # Step 2: Install SELinux components
    install_selinux
    
    # Step 3: Configure SELinux
    configure_selinux
    
    # Step 4: Create custom policies (skip if problematic)
    create_custom_policies
    
    # Step 5: Configure audit integration
    configure_audit_integration
    
    # Step 6: Verify configuration
    verify_selinux_status
    
    # Step 7: Show completion message
    show_reboot_message
    
    HARDN_STATUS "PASS" "SELinux configuration completed successfully"
}

disable_apparmor() {
    HARDN_STATUS "INFO" "Disabling AppArmor to prevent conflicts with SELinux"
    
    # Check if AppArmor is installed
    if systemctl is-enabled apparmor &>/dev/null; then
        HARDN_STATUS "WARNING" "AppArmor is enabled - disabling to prevent MAC conflicts"
        
        # Stop and disable AppArmor
        systemctl stop apparmor
        systemctl disable apparmor
        
        # Remove AppArmor profiles
        if command -v aa-teardown &>/dev/null; then
            aa-teardown
        fi
        
        # Add AppArmor disable to GRUB
        if grep -q "apparmor=0" /etc/default/grub; then
            HARDN_STATUS "INFO" "AppArmor already disabled in GRUB"
        else
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&apparmor=0 /' /etc/default/grub
            update-grub
        fi
        
        HARDN_STATUS "PASS" "AppArmor disabled successfully"
    else
        HARDN_STATUS "INFO" "AppArmor is not enabled"
    fi
}

install_selinux() {
    HARDN_STATUS "INFO" "Installing SELinux components"
    
    # Update package list
    apt update
    
    # Install SELinux packages
    HARDN_STATUS "INFO" "Installing SELinux packages (this may take a few minutes)"
    
    local selinux_packages=(
        "selinux-basics"
        "selinux-policy-default" 
        "selinux-utils"
        "policycoreutils"
        "auditd"
        "audispd-plugins"
    )
    
    # Install optional packages if available
    local optional_packages=(
        "policycoreutils-python-utils"
        "setools"
        "checkpolicy"
    )
    
    # Install core packages
    for package in "${selinux_packages[@]}"; do
        install_package "$package" || {
            HARDN_STATUS "ERROR" "Failed to install required package: $package"
            return 1
        }
    done
    
    # Install optional packages
    for package in "${optional_packages[@]}"; do
        install_package "$package" || {
            HARDN_STATUS "WARNING" "Optional package not available: $package"
        }
    done
    
    HARDN_STATUS "PASS" "SELinux packages installed successfully"
}

configure_selinux() {
    HARDN_STATUS "INFO" "Configuring SELinux for enforcing mode"
    
    # Activate SELinux
    if selinux-activate; then
        HARDN_STATUS "PASS" "SELinux activated successfully"
    else
        HARDN_STATUS "ERROR" "Failed to activate SELinux"
        return 1
    fi
    
    # Configure SELinux policy
    if [[ -f /etc/selinux/config ]]; then
        # Backup the configuration
        backup_file "/etc/selinux/config"
        
        # Set to enforcing mode
        sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
        
        # Set default policy
        sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=default/' /etc/selinux/config
        
        HARDN_STATUS "PASS" "SELinux configured for enforcing mode"
    else
        HARDN_STATUS "ERROR" "SELinux config file not found"
        return 1
    fi
}

create_custom_policies() {
    HARDN_STATUS "INFO" "Skipping custom SELinux policies to avoid compilation errors"
    HARDN_STATUS "WARNING" "Custom HARDN SELinux policies disabled due to potential compatibility issues"
    HARDN_STATUS "INFO" "SELinux will use default system policies which provide good security coverage"
    
    # Instead of custom policies, configure SELinux booleans for better security
    HARDN_STATUS "INFO" "Configuring SELinux security booleans"
    
    local security_booleans=(
        "httpd_can_network_connect=off"
        "httpd_can_sendmail=off"
        "httpd_enable_cgi=off"
        "httpd_enable_homedirs=off"
        "httpd_execmem=off"
        "allow_execheap=off"
        "allow_execmem=off"
        "allow_execstack=off"
    )
    
    for boolean in "${security_booleans[@]}"; do
        if command -v setsebool &>/dev/null; then
            if setsebool -P "$boolean" 2>/dev/null; then
                HARDN_STATUS "INFO" "Set SELinux boolean: $boolean"
            else
                HARDN_STATUS "WARNING" "Could not set SELinux boolean: $boolean"
            fi
        fi
    done
    
    HARDN_STATUS "PASS" "SELinux security configuration completed"
}

configure_audit_integration() {
    log_message "INFO" "Configuring SELinux audit integration..."
    
    # Enable auditd service
    systemctl enable auditd
    systemctl start auditd
    
    # Configure SELinux audit rules
    cat > /etc/audit/rules.d/selinux.rules << 'EOF'
# SELinux audit rules
-w /etc/selinux/ -p wa -k selinux-config
-w /usr/sbin/semanage -p x -k selinux-manage
-w /usr/sbin/setsebool -p x -k selinux-bool
-w /usr/sbin/semodule -p x -k selinux-module
EOF

    # Reload audit rules
    augenrules --load
    
    log_message "SUCCESS" "SELinux audit integration configured"
}

verify_selinux_status() {
    log_message "INFO" "Verifying SELinux configuration..."
    
    echo "SELinux Status:"
    echo "==============="
    
    if command -v sestatus &>/dev/null; then
        sestatus
        
        # Check if enforcing
        if sestatus | grep -q "Current mode.*enforcing"; then
            log_message "SUCCESS" "SELinux is running in enforcing mode"
        elif sestatus | grep -q "Current mode.*permissive"; then
            log_message "WARN" "SELinux is in permissive mode - reboot required for enforcing"
        else
            log_message "ERROR" "SELinux is disabled"
            return 1
        fi
    else
        log_message "ERROR" "SELinux tools not available"
        return 1
    fi
    
    echo ""
    echo "SELinux Policy Information:"
    echo "=========================="
    semanage boolean -l | head -10
    
    return 0
}

show_reboot_notice() {
    log_message "WARN" "REBOOT REQUIRED: SELinux changes require system reboot"
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════╗
║                        REBOOT REQUIRED                      ║
║                                                              ║
║  SELinux has been configured but requires a system reboot   ║
║  to become fully active in enforcing mode.                  ║
║                                                              ║
║  After reboot, verify status with: sestatus                 ║
║                                                              ║
║  IMPORTANT: Ensure you have alternate access to the system  ║
║  in case of SELinux policy conflicts after reboot.         ║
╚══════════════════════════════════════════════════════════════╝

EOF
}

main() {
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    
    check_root
    
    log_message "INFO" "Starting HARDN SELinux configuration..."
    
    # Step 1: Disable AppArmor to prevent conflicts
    disable_apparmor
    
    # Step 2: Install SELinux components
    install_selinux
    
    # Step 3: Configure SELinux
    configure_selinux
    
    # Step 4: Create custom policies
    create_custom_policies
    
    # Step 5: Configure audit integration
    configure_audit_integration
    
    # Step 6: Verify configuration
    if verify_selinux_status; then
        log_message "SUCCESS" "SELinux configuration completed successfully"
    else
        log_message "ERROR" "SELinux configuration verification failed"
        exit 1
    fi
    
    # Step 7: Show reboot notice
    show_reboot_notice

    printf "[HARDN] selinux.sh executed at $(date)\n" | tee -a /var/log/hardn/hardn-tools.log
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
