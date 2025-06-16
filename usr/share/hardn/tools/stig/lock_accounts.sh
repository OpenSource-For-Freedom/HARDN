#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG Account Lockdown - Lock inactive accounts after 35 days
# Implements DISA STIG requirements for account management

configure_account_lockdown() {
    HARDN_STATUS "INFO" "Configuring STIG account lockdown policies"
    
    # Set default inactive period for new accounts (35 days per STIG)
    HARDN_STATUS "INFO" "Setting default inactive period to 35 days for new accounts"
    if useradd -D -f 35; then
        HARDN_STATUS "PASS" "Default inactive period set to 35 days for new accounts"
    else
        HARDN_STATUS "ERROR" "Failed to set default inactive period"
        return 1
    fi
    
    # Apply inactive period to existing user accounts (UID >= 1000, exclude nobody)
    HARDN_STATUS "INFO" "Applying 35-day inactive period to existing user accounts"
    
    local users_modified=0
    local users_failed=0
    local total_users
    total_users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)
    
    if [ "$total_users" -gt 0 ]; then
        awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
            if chage --inactive 35 "$user" 2>/dev/null; then
                HARDN_STATUS "INFO" "Set inactive period for user: $user"
                ((users_modified++))
            else
                HARDN_STATUS "WARNING" "Failed to set inactive period for user: $user"
                ((users_failed++))
            fi
        done
        HARDN_STATUS "PASS" "Account lockdown applied to $total_users user accounts"
    else
        HARDN_STATUS "INFO" "No regular user accounts found to modify"
    fi
    
    
    # Verify configuration
    HARDN_STATUS "INFO" "Verifying account lockdown configuration"
    
    # Check default settings
    local default_inactive
    default_inactive=$(useradd -D | grep INACTIVE | cut -d= -f2)
    
    if [ "$default_inactive" = "35" ]; then
        HARDN_STATUS "PASS" "Default inactive period correctly set to 35 days"
    else
        HARDN_STATUS "WARNING" "Default inactive period is $default_inactive (expected 35)"
    fi
    
    # Display current user account status
    HARDN_STATUS "INFO" "Current user account inactive settings:"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        local inactive_days
        inactive_days=$(chage -l "$user" 2>/dev/null | grep "Account inactive" | awk '{print $3}')
        if [ -n "$inactive_days" ] && [ "$inactive_days" != "never" ]; then
            HARDN_STATUS "INFO" "  $user: $inactive_days days"
        else
            HARDN_STATUS "INFO" "  $user: never"
        fi
    done
    
    HARDN_STATUS "PASS" "STIG account lockdown configuration completed"
}

# Additional account security hardening
configure_additional_account_security() {
    HARDN_STATUS "INFO" "Applying additional account security measures"
    
    # Set password aging for existing accounts if not already set
    HARDN_STATUS "INFO" "Checking password aging settings"
    
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        # Get current password aging info
        local max_days min_days warn_days
        max_days=$(chage -l "$user" 2>/dev/null | grep "Maximum number" | awk '{print $NF}')
        min_days=$(chage -l "$user" 2>/dev/null | grep "Minimum number" | awk '{print $NF}')
        warn_days=$(chage -l "$user" 2>/dev/null | grep "Number of days of warning" | awk '{print $NF}')
        
        # Apply STIG-compliant password aging if not set
        local needs_update=false
        
        if [ "$max_days" = "-1" ] || [ "$max_days" -gt 90 ]; then
            chage -M 90 "$user" 2>/dev/null && needs_update=true
        fi
        
        if [ "$min_days" = "-1" ] || [ "$min_days" -lt 1 ]; then
            chage -m 1 "$user" 2>/dev/null && needs_update=true
        fi
        
        if [ "$warn_days" = "-1" ] || [ "$warn_days" -lt 7 ]; then
            chage -W 7 "$user" 2>/dev/null && needs_update=true
        fi
        
        if [ "$needs_update" = "true" ]; then
            HARDN_STATUS "INFO" "Updated password aging for user: $user"
        fi
    done
    
    HARDN_STATUS "PASS" "Additional account security measures applied"
}

main() {
    check_root
    log_tool_execution "lock_accounts.sh" "STIG account lockdown configuration"
    
    HARDN_STATUS "INFO" "Starting STIG Account Lockdown configuration"
    
    configure_account_lockdown
    configure_additional_account_security
    
    HARDN_STATUS "PASS" "STIG Account Lockdown completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi