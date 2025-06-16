#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: cleanup.sh  
# Purpose: System security cleanup and maintenance
# Location: /src/tools/cleanup.sh

check_root
log_tool_execution "cleanup.sh"

system_cleanup() {
    HARDN_STATUS "info" "Starting system security cleanup..."
    
    # Clean package cache
    HARDN_STATUS "info" "Cleaning package cache..."
    if apt-get clean && apt-get autoclean; then
        HARDN_STATUS "pass" "Package cache cleaned successfully"
    else
        HARDN_STATUS "warning" "Failed to clean package cache"
    fi
    
    # Remove unused packages
    HARDN_STATUS "info" "Removing unused packages..."
    if apt-get autoremove -y; then
        HARDN_STATUS "pass" "Unused packages removed successfully"
    else
        HARDN_STATUS "warning" "Failed to remove some unused packages"
    fi
    
    # Clean temporary files
    HARDN_STATUS "info" "Cleaning temporary files..."
    if rm -rf /tmp/* /var/tmp/* 2>/dev/null; then
        HARDN_STATUS "pass" "Temporary files cleaned"
    else
        HARDN_STATUS "warning" "Some temporary files could not be removed"
    fi
    
    # Clean old log files
    HARDN_STATUS "info" "Cleaning old log files..."
    find /var/log -name "*.log.*.gz" -mtime +30 -delete 2>/dev/null || true
    find /var/log -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
    HARDN_STATUS "pass" "Old log files cleaned"
    
    # Update file permissions for security
    HARDN_STATUS "info" "Updating critical file permissions..."
    chmod 600 /etc/shadow /etc/gshadow 2>/dev/null || true
    chmod 644 /etc/passwd /etc/group 2>/dev/null || true
    HARDN_STATUS "pass" "Critical file permissions updated"
    
    HARDN_STATUS "pass" "System cleanup completed. Unused packages and cache cleared"
    
    # Show completion message
    log_info "HARDN cleanup completed successfully. Reboot recommended."
    
    HARDN_STATUS "info" "System cleanup completed successfully. Reboot recommended for all changes to take effect"
}

main() {
    system_cleanup
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

