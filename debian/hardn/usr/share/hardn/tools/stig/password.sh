#!/bin/bash

source "$(cd "$(dirname "$0")/.." && pwd)/functions.sh"

# HARDN STIG Tool: password.sh
# Purpose: Apply DISA STIG password policy requirements
# Location: /src/tools/stig/password.sh

check_root
log_tool_execution "stig/password.sh"

apply_stig_password_policy() {
    HARDN_STATUS "info" "Applying DISA STIG password policy requirements..."
    
    # Install PAM password quality module
    if install_package libpam-pwquality; then
        HARDN_STATUS "pass" "PAM password quality module installed"
    else
        HARDN_STATUS "error" "Failed to install PAM password quality module"
        return 1
    fi
    
    # Configure password quality requirements
    HARDN_STATUS "info" "Configuring password quality settings..."
    
    backup_file "/etc/security/pwquality.conf"
    
    sed -i 's/^# minlen.*/minlen = 14/' /etc/security/pwquality.conf
    sed -i 's/^# dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^# ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^# ocredit.*/ocredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^# lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
    
    HARDN_STATUS "pass" "Password quality requirements configured"
    
    # Configure PAM password module
    if [ -f /etc/pam.d/common-password ]; then
        backup_file "/etc/pam.d/common-password"
        
        if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
            echo "password requisite pam_pwquality.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" >> /etc/pam.d/common-password
        else
            sed -i '/pam_pwquality.so/ s/$/ retry=3 enforce_for_root/' /etc/pam.d/common-password
        fi
        HARDN_STATUS "pass" "PAM password configuration updated"
    else
        HARDN_STATUS "warning" "PAM common-password file not found"
    fi
    
    HARDN_STATUS "pass" "STIG password policy applied successfully"
}

main() {
    apply_stig_password_policy
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
