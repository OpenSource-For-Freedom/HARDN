#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: ntp.sh
# Purpose: NTP Configuration Script - Configures NTP daemon for time synchronization
# Location: /src/tools/ntp.sh

check_root
log_tool_execution "ntp.sh"

setup_ntp() {
    HARDN_STATUS "info" "Setting up NTP daemon..."

    local ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
    local configured=false

    # Prefer systemd-timesyncd if active
    if systemctl is-active --quiet systemd-timesyncd; then
        HARDN_STATUS "info" "systemd-timesyncd is active. Configuring..."
        local timesyncd_conf="/etc/systemd/timesyncd.conf"
        local temp_timesyncd_conf
        temp_timesyncd_conf=$(mktemp)

        if [[ ! -f "$timesyncd_conf" ]]; then
            HARDN_STATUS "info" "Creating $timesyncd_conf as it does not exist."
            echo "[Time]" > "$timesyncd_conf"
            chmod 644 "$timesyncd_conf"
        fi

        cp "$timesyncd_conf" "$temp_timesyncd_conf"

        # Set NTP= explicitly
        if grep -qE "^\s*NTP=" "$temp_timesyncd_conf"; then
            sed -i -E "s/^\s*NTP=.*/NTP=$ntp_servers/" "$temp_timesyncd_conf"
        else
            if grep -q "\[Time\]" "$temp_timesyncd_conf"; then
                sed -i "/\[Time\]/a NTP=$ntp_servers" "$temp_timesyncd_conf"
            else
                echo -e "\n[Time]\nNTP=$ntp_servers" >> "$temp_timesyncd_conf"
            fi
        fi

        if ! cmp -s "$temp_timesyncd_conf" "$timesyncd_conf"; then
            cp "$temp_timesyncd_conf" "$timesyncd_conf"
            HARDN_STATUS "pass" "Updated $timesyncd_conf. Restarting systemd-timesyncd..."
            if systemctl restart systemd-timesyncd; then
                HARDN_STATUS "pass" "systemd-timesyncd restarted successfully."
                configured=true
            else
                HARDN_STATUS "error" "Failed to restart systemd-timesyncd. Manual check required."
            fi
        else
            HARDN_STATUS "info" "No effective changes to $timesyncd_conf were needed."
            configured=true # Already configured correctly or no changes needed
        fi
        rm -f "$temp_timesyncd_conf"

        # Check NTP peer stratum and warn if not stratum 1 or 2
        if timedatectl show-timesync --property=ServerAddress,NTP,Synchronized 2>/dev/null | grep -q "Synchronized=yes"; then
            ntpstat_output=$(ntpq -c rv 2>/dev/null)
            stratum=$(echo "$ntpstat_output" | grep -o 'stratum=[0-9]*' | cut -d= -f2)
            if [[ -n "$stratum" && "$stratum" -gt 2 ]]; then
                HARDN_STATUS "warning" "NTP is synchronized but using a high stratum peer (stratum $stratum). Consider using a lower stratum (closer to 1) for better accuracy."
            fi
        fi

    # Fallback to ntpd if systemd-timesyncd is not active
    else
        HARDN_STATUS "info" "systemd-timesyncd is not active. Checking/Configuring ntpd..."

        local ntp_package_installed=false
        # Ensure ntp package is installed
        if dpkg -s ntp >/dev/null 2>&1; then
             HARDN_STATUS "pass" "ntp package is already installed."
             ntp_package_installed=true
        else
             HARDN_STATUS "info" "ntp package not found. Attempting to install..."
             # Attempt installation, check exit status
             if apt-get update >/dev/null 2>&1 && apt-get install -y ntp >/dev/null 2>&1; then
                 HARDN_STATUS "pass" "ntp package installed successfully."
                 ntp_package_installed=true
             else
                 HARDN_STATUS "error" "Failed to install ntp package. Skipping NTP configuration."
                 configured=false # Ensure configured is false on failure
                 # Do not return here, allow the rest of setup_security to run
             fi
        fi
    fi
    
    # Return configuration status
    if [[ "$configured" == "true" ]]; then
        HARDN_STATUS "pass" "NTP configuration completed successfully"
        return 0
    else
        HARDN_STATUS "error" "NTP configuration failed"
        return 1
    fi
}

# Main execution
main() {
    setup_ntp
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi