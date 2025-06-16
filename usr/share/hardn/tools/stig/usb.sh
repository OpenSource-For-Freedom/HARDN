#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG USB Storage Disable
# Implements DISA STIG requirements for USB storage security

stig_disable_usb() {
    HARDN_STATUS "INFO" "Disabling USB storage devices per STIG requirements"
    
    # Create modprobe configuration to blacklist USB storage
    local modprobe_conf="/etc/modprobe.d/hardn-usb-blacklist.conf"
    
    # Backup existing configuration if it exists
    if [ -f "$modprobe_conf" ]; then
        backup_file "$modprobe_conf"
    fi
    
    # Create USB storage blacklist configuration
    cat <<EOF > "$modprobe_conf"
# STIG USB Storage Security Configuration
# Disable USB storage devices to prevent unauthorized data transfer
install usb-storage /bin/false
blacklist usb-storage

# Additional USB security measures
install uas /bin/false
blacklist uas
EOF
    
    # Set proper permissions
    chmod 644 "$modprobe_conf"
    chown root:root "$modprobe_conf"
    
    HARDN_STATUS "INFO" "USB storage blacklist configuration created"
    
    # Update initramfs to apply changes
    HARDN_STATUS "INFO" "Updating initramfs to apply USB restrictions"
    if update-initramfs -u; then
        HARDN_STATUS "PASS" "Initramfs updated successfully"
    else
        HARDN_STATUS "ERROR" "Failed to update initramfs"
        return 1
    fi
    
    # Remove any currently loaded USB storage modules
    HARDN_STATUS "INFO" "Attempting to remove loaded USB storage modules"
    if lsmod | grep -q usb_storage; then
        if rmmod usb_storage 2>/dev/null; then
            HARDN_STATUS "PASS" "USB storage module removed"
        else
            HARDN_STATUS "WARNING" "USB storage module could not be removed (may be in use)"
        fi
    else
        HARDN_STATUS "INFO" "USB storage module not currently loaded"
    fi
    
    # Configure udev rules for additional USB security
    local udev_rule="/etc/udev/rules.d/99-hardn-usb-security.rules"
    
    cat <<EOF > "$udev_rule"
# STIG USB Security Rules
# Block USB mass storage devices
SUBSYSTEM=="usb", ATTR{bDeviceClass}=="08", ACTION=="add", RUN+="/bin/sh -c 'echo 1 > /sys/\$devpath/remove'"

# Log USB device connections for security monitoring
SUBSYSTEM=="usb", ACTION=="add", RUN+="/bin/logger -t USB-SECURITY 'USB device connected: \$env{ID_VENDOR} \$env{ID_MODEL}'"
SUBSYSTEM=="usb", ACTION=="remove", RUN+="/bin/logger -t USB-SECURITY 'USB device disconnected: \$env{ID_VENDOR} \$env{ID_MODEL}'"
EOF
    
    chmod 644 "$udev_rule"
    chown root:root "$udev_rule"
    
    # Reload udev rules
    if udevadm control --reload-rules; then
        HARDN_STATUS "PASS" "USB security udev rules configured"
    else
        HARDN_STATUS "WARNING" "Failed to reload udev rules"
    fi
    
    HARDN_STATUS "PASS" "USB storage security configuration completed"
}

main() {
    check_root
    log_tool_execution "usb.sh" "STIG USB storage security configuration"
    
    HARDN_STATUS "INFO" "Starting STIG USB storage security configuration"
    
    stig_disable_usb
    
    HARDN_STATUS "PASS" "STIG USB storage security configuration completed successfully"
    HARDN_STATUS "WARNING" "System reboot recommended to fully apply USB restrictions"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi