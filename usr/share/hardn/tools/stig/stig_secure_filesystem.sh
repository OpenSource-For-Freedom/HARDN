#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG Secure Filesystem (Simplified Version)
# Implements basic DISA STIG requirements for filesystem security

configure_filesystem_permissions() {
    HARDN_STATUS "INFO" "Configuring filesystem permissions per STIG requirements"
    
    # Set permissions on critical system files
    HARDN_STATUS "INFO" "Setting permissions on critical system files"
    chown root:root /etc/passwd /etc/group /etc/gshadow
    chmod 644 /etc/passwd /etc/group
    chown root:shadow /etc/shadow /etc/gshadow
    chmod 640 /etc/shadow /etc/gshadow
    
    HARDN_STATUS "PASS" "System file permissions configured"
}

configure_audit_rules() {
    HARDN_STATUS "INFO" "Configuring audit rules for filesystem monitoring"
    
    # Install audit packages
    install_package "auditd" || {
        HARDN_STATUS "ERROR" "Failed to install auditd"
        return 1
    }
    
    install_package "audispd-plugins" || {
        HARDN_STATUS "WARNING" "Failed to install audispd-plugins"
    }
    
    # Create audit rules directory
    mkdir -p /etc/audit/rules.d
    
    # Create STIG audit rules
    local audit_rules="/etc/audit/rules.d/stig.rules"
    
    if [ -f "$audit_rules" ]; then
        backup_file "$audit_rules"
    fi
    
    cat > "$audit_rules" <<EOF
# STIG Audit Rules for Filesystem Monitoring
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-e 2
EOF
    
    # Set proper permissions on audit rules
    chown root:root /etc/audit/rules.d/*.rules
    chmod 600 /etc/audit/rules.d/*.rules
    
    # Configure audit log directory
    mkdir -p /var/log/audit
    chown -R root:root /var/log/audit
    chmod 700 /var/log/audit
    
    # Load audit rules and start service
    HARDN_STATUS "INFO" "Loading audit rules and starting audit service"
    
    if augenrules --load; then
        HARDN_STATUS "PASS" "Audit rules loaded successfully"
    else
        HARDN_STATUS "WARNING" "Failed to load audit rules"
    fi
    
    # Enable and start audit service
    enable_service "auditd"
    
    if systemctl start auditd; then
        HARDN_STATUS "PASS" "Audit service started successfully"
    else
        HARDN_STATUS "ERROR" "Failed to start audit service"
        return 1
    fi
    
    # Enable audit system
    if auditctl -e 1; then
        HARDN_STATUS "PASS" "Audit system enabled"
    else
        HARDN_STATUS "WARNING" "Failed to enable audit system"
    fi
    
    HARDN_STATUS "PASS" "Audit configuration completed"
}

main() {
    check_root
    log_tool_execution "stig_secure_filesystem.sh" "STIG filesystem security (simplified)"
    
    HARDN_STATUS "INFO" "Starting STIG filesystem security configuration (simplified version)"
    
    configure_filesystem_permissions
    configure_audit_rules
    
    HARDN_STATUS "PASS" "STIG filesystem security configuration completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi