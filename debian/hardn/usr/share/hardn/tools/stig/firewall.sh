#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG UFW Firewall Configuration
# Implements DISA STIG requirements for network security

main() {
    check_root
    log_tool_execution "firewall.sh" "STIG UFW firewall configuration"
    
    HARDN_STATUS "INFO" "Starting STIG UFW firewall configuration"
    
    # Install UFW if not present
    if ! command -v ufw > /dev/null 2>&1; then
        HARDN_STATUS "WARNING" "UFW is not installed. Installing UFW..."
        install_package "ufw" || {
            HARDN_STATUS "ERROR" "Failed to install UFW"
            return 1
        }
    fi
    
    # Reset UFW to default settings
    HARDN_STATUS "INFO" "Resetting UFW to default settings"
    ufw --force reset || {
        HARDN_STATUS "ERROR" "Failed to reset UFW"
        return 1
    }
    
    # Set UFW default policies
    HARDN_STATUS "INFO" "Setting UFW default policies"
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential outbound traffic
    HARDN_STATUS "INFO" "Configuring outbound traffic rules"
    ufw allow out 80/tcp comment "HTTP outbound"
    ufw allow out 443/tcp comment "HTTPS outbound"
    
    # Allow DNS resolution and NTP
    HARDN_STATUS "INFO" "Allowing DNS and NTP traffic"
    ufw allow out 53/udp comment "DNS UDP"
    ufw allow out 53/tcp comment "DNS TCP"
    ufw allow out 123/udp comment "NTP time sync"
    
    # Allow Debian repository access
    HARDN_STATUS "INFO" "Configuring Debian repository access"
    ufw allow out to archive.debian.org port 80 proto tcp comment "Debian archive"
    ufw allow out to security.debian.org port 443 proto tcp comment "Debian security"
    
    # Configure logging
    HARDN_STATUS "INFO" "Enabling UFW logging"
    ufw logging on
    
    # Enable UFW
    HARDN_STATUS "INFO" "Enabling UFW firewall"
    echo "y" | ufw enable || {
        HARDN_STATUS "ERROR" "Failed to enable UFW"
        return 1
    }
    
    # Reload configuration
    ufw reload || {
        HARDN_STATUS "ERROR" "Failed to reload UFW"
        return 1
    }
    
    # Display status
    HARDN_STATUS "INFO" "UFW firewall status:"
    ufw status verbose
    
    HARDN_STATUS "PASS" "STIG UFW firewall configuration completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
