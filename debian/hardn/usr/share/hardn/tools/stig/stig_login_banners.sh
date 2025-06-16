#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG Login Banners (Simplified Version)
# Implements basic DISA STIG requirements for login banners

main() {
    check_root
    log_tool_execution "stig_login_banners.sh" "STIG login banners (simplified)"
    
    HARDN_STATUS "INFO" "Starting STIG login banners configuration (simplified version)"
    
    # Backup existing files
    if [ -f /etc/issue ]; then
        backup_file /etc/issue
    fi
    
    if [ -f /etc/issue.net ]; then
        backup_file /etc/issue.net
    fi
    
    # Configure login banners
    HARDN_STATUS "INFO" "Configuring STIG-compliant login banners"
    
    local banner_text="You are accessing a fully secured STIG Information System (IS).
Use of this IS constitutes consent to monitoring.
Unauthorized access is prohibited and punishable by law."
    
    echo "$banner_text" > /etc/issue
    echo "$banner_text" > /etc/issue.net
    
    # Set proper permissions
    chmod 644 /etc/issue /etc/issue.net
    chown root:root /etc/issue /etc/issue.net
    
    HARDN_STATUS "PASS" "STIG login banners configured successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi