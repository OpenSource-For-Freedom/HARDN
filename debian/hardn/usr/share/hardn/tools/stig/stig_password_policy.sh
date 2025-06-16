#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG Password Policy (Simplified Version)
# Implements basic DISA STIG requirements for password policy

main() {
    check_root
    log_tool_execution "stig_password_policy.sh" "STIG password policy (simplified)"
    
    HARDN_STATUS "INFO" "Starting STIG password policy configuration (simplified version)"
    
    # Install password quality library
    HARDN_STATUS "INFO" "Installing password quality library"
    install_package "libpam-pwquality" || {
        HARDN_STATUS "ERROR" "Failed to install libpam-pwquality"
        return 1
    }
    
    # Configure password quality
    HARDN_STATUS "INFO" "Configuring password quality settings"
    local pwquality_conf="/etc/security/pwquality.conf"
    
    if [ -f "$pwquality_conf" ]; then
        backup_file "$pwquality_conf"
    fi
    
    # Apply STIG password requirements
    sed -i 's/^# minlen.*/minlen = 14/' "$pwquality_conf"
    sed -i 's/^# dcredit.*/dcredit = -1/' "$pwquality_conf"
    sed -i 's/^# ucredit.*/ucredit = -1/' "$pwquality_conf"
    sed -i 's/^# ocredit.*/ocredit = -1/' "$pwquality_conf"
    sed -i 's/^# lcredit.*/lcredit = -1/' "$pwquality_conf"
    
    # Configure PAM for password quality
    HARDN_STATUS "INFO" "Configuring PAM password quality enforcement"
    local pam_password="/etc/pam.d/common-password"
    
    if [ -f "$pam_password" ]; then
        backup_file "$pam_password"
        
        # Add password quality enforcement if not already present
        if ! grep -q "retry=3 enforce_for_root" "$pam_password"; then
            sed -i '/pam_pwquality.so/ s/$/ retry=3 enforce_for_root/' "$pam_password" 2>/dev/null || true
        fi
    fi
    
    HARDN_STATUS "PASS" "STIG password policy configured successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi