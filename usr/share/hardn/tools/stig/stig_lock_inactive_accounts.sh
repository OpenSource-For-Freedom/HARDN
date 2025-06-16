#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG Lock Inactive Accounts (Simplified Version)
# Implements basic DISA STIG requirements for inactive account lockdown

main() {
    check_root
    log_tool_execution "stig_lock_inactive_accounts.sh" "STIG inactive account lockdown (simplified)"
    
    HARDN_STATUS "INFO" "Starting STIG inactive account lockdown (simplified version)"
    
    # Set default inactive period for new accounts (35 days per STIG)
    HARDN_STATUS "INFO" "Setting default inactive period to 35 days"
    if useradd -D -f 35; then
        HARDN_STATUS "PASS" "Default inactive period set to 35 days"
    else
        HARDN_STATUS "ERROR" "Failed to set default inactive period"
        return 1
    fi
    
    # Apply to existing user accounts
    HARDN_STATUS "INFO" "Applying inactive period to existing user accounts"
    local users_processed=0
    
    for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
        if chage --inactive 35 "$user" 2>/dev/null; then
            HARDN_STATUS "INFO" "Set inactive period for user: $user"
            ((users_processed++))
        else
            HARDN_STATUS "WARNING" "Failed to set inactive period for user: $user"
        fi
    done
    
    HARDN_STATUS "PASS" "STIG inactive account lockdown completed - processed $users_processed users"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi