#!/bin/bash

source "$(cd "$(dirname "$0")/.." && pwd)/functions.sh"

# HARDN STIG Tool: filesystems.sh
# Purpose: Secure filesystem permissions according to STIG requirements
# Location: /src/tools/stig/filesystems.sh

check_root
log_tool_execution "stig/filesystems.sh"

secure_filesystem_permissions() {
    HARDN_STATUS "info" "Securing filesystem permissions according to STIG requirements..."
    
    # Secure critical system files
    HARDN_STATUS "info" "Setting secure permissions on critical system files..."
    chown root:root /etc/passwd /etc/group /etc/gshadow
    chmod 644 /etc/passwd /etc/group
    chown root:shadow /etc/shadow /etc/gshadow
    chmod 640 /etc/shadow /etc/gshadow
    HARDN_STATUS "pass" "Critical system file permissions secured"

    # Configure audit rules
    HARDN_STATUS "info" "Configuring audit rules for filesystem monitoring..."
    if install_package "auditd audispd-plugins"; then
        HARDN_STATUS "pass" "Audit packages installed"
    else
        HARDN_STATUS "error" "Failed to install audit packages"
        return 1
    fi
    
    # Create STIG audit rules
    cat > /etc/audit/rules.d/stig.rules << 'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-e 2
EOF

    chown root:root /etc/audit/rules.d/*.rules
    chmod 600 /etc/audit/rules.d/*.rules
    HARDN_STATUS "pass" "STIG audit rules configured"
    
    # Create audit log directory with proper permissions
    mkdir -p /var/log/audit
    chown -R root:root /var/log/audit
    chmod 700 /var/log/audit
    HARDN_STATUS "pass" "Audit log directory permissions set"

    # Load audit rules and enable auditd
    HARDN_STATUS "info" "Loading audit rules and enabling auditd service..."
    augenrules --load 2>/dev/null || HARDN_STATUS "warning" "Failed to load audit rules"
    
    if enable_service auditd; then
        HARDN_STATUS "pass" "Auditd service enabled and started"
    else
        HARDN_STATUS "error" "Failed to enable auditd service"
        return 1
    fi
    
    # Enable audit system
    if auditctl -e 1 2>/dev/null; then
        HARDN_STATUS "pass" "Audit system enabled"
    else
        HARDN_STATUS "warning" "Failed to enable audit system"
    fi
    
    HARDN_STATUS "pass" "STIG filesystem security configuration completed"
}

main() {
    secure_filesystem_permissions
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
