#!/bin/bash

source "$(cd "$(dirname "$0")/.." && pwd)/functions.sh"

# HARDN STIG Tool: banners.sh
# Purpose: Configure STIG compliant login banners
# Location: /src/tools/stig/banners.sh

check_root
log_tool_execution "stig/banners.sh"

configure_stig_banner() {
    HARDN_STATUS "info" "Configuring STIG compliant banner for remote logins (/etc/issue.net)..."
    
    local banner_net_file="/etc/issue.net"
    if [ -f "$banner_net_file" ]; then
        # Backup existing banner file
        backup_file "$banner_net_file"
    else
        touch "$banner_net_file"
    fi
    
    # Write the STIG compliant banner
    cat > "$banner_net_file" << 'EOF'
*************************************************************
*     ############# H A R D N - X D R ##############        *
*  This system is for the use of authorized SIG users.      *
*  Individuals using this computer system without authority *
*  or in excess of their authority are subject to having    *
*  all of their activities on this system monitored and     *
*  In the course of monitoring individuals improperly using   *
*  this system, or in the course of system maintenance, the  *
*  activities of authorized users may also be monitored.     *
*                                                           *
*  Anyone using this system expressly consents to such      *
*  monitoring and is advised that if such monitoring        *
*  reveals evidence of criminal activity, system personnel  *
*  may provide the evidence from such monitoring to law     *
*  enforcement officials.                                   *
*                                                           *
*************************************************************
EOF

    chmod 644 "$banner_net_file"
    HARDN_STATUS "pass" "STIG compliant banner configured in $banner_net_file"
    
    # Configure local console banner (/etc/issue)
    HARDN_STATUS "info" "Configuring STIG compliant banner for local logins (/etc/issue)..."
    cp "$banner_net_file" /etc/issue
    HARDN_STATUS "pass" "STIG compliant banner configured in /etc/issue"
    
    # Configure SSH banner in sshd_config
    HARDN_STATUS "info" "Configuring SSH banner reference..."
    if [ -f /etc/ssh/sshd_config ]; then
        backup_file "/etc/ssh/sshd_config"
        if ! grep -q "^Banner /etc/issue.net" /etc/ssh/sshd_config; then
            echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
            HARDN_STATUS "pass" "SSH banner reference added to sshd_config"
        else
            HARDN_STATUS "pass" "SSH banner reference already configured"
        fi
    fi
}

main() {
    configure_stig_banner
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi