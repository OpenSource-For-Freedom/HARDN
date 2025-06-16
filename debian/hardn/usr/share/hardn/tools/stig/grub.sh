#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG GRUB Bootloader Security Configuration
# Implements DISA STIG requirements for bootloader security

main() {
    check_root
    log_tool_execution "grub.sh" "STIG GRUB bootloader security configuration"
    
    HARDN_STATUS "INFO" "Starting STIG GRUB bootloader security configuration"
    
    # Detect system type and set appropriate paths
    if [ -d /sys/firmware/efi ]; then
        SYSTEM_TYPE="EFI"
        GRUB_CFG="/etc/grub.d/41_custom"
        GRUB_MAIN_CFG="/boot/grub/grub.cfg"
    else
        SYSTEM_TYPE="BIOS"
        GRUB_CFG="/etc/grub.d/40_custom"
        GRUB_MAIN_CFG="/boot/grub/grub.cfg"
    fi
    
    GRUB_DEFAULT="/etc/default/grub"
    GRUB_USER="grubadmin"
    CUSTOM_CFG="/boot/grub/custom.cfg"
    
    HARDN_STATUS "INFO" "Detected $SYSTEM_TYPE boot system"
    
    # Generate a secure random password for GRUB
    GRUB_PASSWORD=$(openssl rand -base64 32 | cut -c1-16)
    
    HARDN_STATUS "WARNING" "GRUB password generated: $GRUB_PASSWORD"
    HARDN_STATUS "WARNING" "Please save this password securely - you'll need it for system recovery!"

    
    # Install required packages
    if [ "$SYSTEM_TYPE" = "BIOS" ] && ! dpkg -l | grep -q grub-pc; then
        HARDN_STATUS "INFO" "Installing grub-pc for BIOS system"
        install_package "grub-pc" || {
            HARDN_STATUS "ERROR" "Failed to install grub-pc"
            return 1
        }
    fi
    
    # For EFI systems, ensure grub-efi is properly configured
    if [ "$SYSTEM_TYPE" = "EFI" ] && ! dpkg -l | grep -q grub-efi; then
        HARDN_STATUS "WARNING" "GRUB EFI not fully configured. Ensure system is properly installed"
    fi
    
    # Generate password hash
    HARDN_STATUS "INFO" "Generating secure password hash"
    GRUB_HASH=$(echo -e "$GRUB_PASSWORD\n$GRUB_PASSWORD" | grub-mkpasswd-pbkdf2 | grep "PBKDF2 hash of your password is" | sed 's/PBKDF2 hash of your password is //')
    
    # Validate hash was generated
    if [ -z "$GRUB_HASH" ]; then
        HARDN_STATUS "ERROR" "Failed to generate GRUB password hash"
        return 1
    fi

    
    # Backup existing configurations
    HARDN_STATUS "INFO" "Backing up existing GRUB configurations"
    if [ -f "$GRUB_CFG" ]; then
        backup_file "$GRUB_CFG"
    fi
    
    if [ -f "$GRUB_MAIN_CFG" ]; then
        backup_file "$GRUB_MAIN_CFG"
    fi
    
    # Create custom.cfg with password protection
    HARDN_STATUS "INFO" "Creating GRUB password configuration"
    cat <<EOF > "$CUSTOM_CFG"
set superusers="$GRUB_USER"
password_pbkdf2 $GRUB_USER $GRUB_HASH
EOF
    
    # Update the custom GRUB file to load our config
    cat <<EOF > "$GRUB_CFG"
#!/bin/sh
cat <<'GRUB_EOF'
if [ -f \${config_directory}/custom.cfg ]; then
  source \${config_directory}/custom.cfg
elif [ -z "\${config_directory}" -a -f \$prefix/custom.cfg ]; then
  source \$prefix/custom.cfg
fi
GRUB_EOF
EOF
    
    chmod +x "$GRUB_CFG"

    
    # Apply GRUB security settings
    HARDN_STATUS "INFO" "Applying GRUB security settings"
    
    # Restrict access to GRUB configuration files
    if [ -f "$GRUB_MAIN_CFG" ]; then
        chmod 600 "$GRUB_MAIN_CFG"
        chown root:root "$GRUB_MAIN_CFG"
    fi
    
    # Restrict access to custom config
    chmod 600 "$CUSTOM_CFG"
    chown root:root "$CUSTOM_CFG"
    
    # Restrict access to /etc/grub.d and /etc/default/grub
    chmod -R go-rwx /etc/grub.d
    chmod 600 /etc/default/grub
    chown root:root /etc/default/grub
    
    # Configure additional GRUB security parameters
    backup_file "$GRUB_DEFAULT"
    
    # Update GRUB default configuration for security
    cat <<EOF >> "$GRUB_DEFAULT"

# STIG Security Settings
GRUB_RECORDFAIL_TIMEOUT=30
GRUB_TIMEOUT=5
GRUB_DISABLE_RECOVERY=true
GRUB_DISABLE_OS_PROBER=true
EOF
    
    # Update GRUB configuration
    HARDN_STATUS "INFO" "Updating GRUB configuration"
    update-grub || {
        HARDN_STATUS "ERROR" "Failed to update GRUB configuration"
        return 1
    }
    
    # Verify GRUB configuration if possible
    if command -v grub-script-check >/dev/null 2>&1; then
        HARDN_STATUS "INFO" "Verifying GRUB configuration syntax"
        if ! grub-script-check "$GRUB_MAIN_CFG" 2>/dev/null; then
            HARDN_STATUS "ERROR" "GRUB configuration has syntax issues!"
            return 1
        fi
    else
        HARDN_STATUS "WARNING" "grub-script-check not available, skipping syntax validation"
    fi
    
    # Create GRUB password file for admin reference
    echo "$GRUB_PASSWORD" > /root/.grub_password
    chmod 600 /root/.grub_password
    chown root:root /root/.grub_password
    
    HARDN_STATUS "PASS" "GRUB bootloader security configuration completed"
    HARDN_STATUS "INFO" "Configuration details:"
    HARDN_STATUS "INFO" "  - System Type: $SYSTEM_TYPE"
    HARDN_STATUS "INFO" "  - GRUB User: $GRUB_USER"
    HARDN_STATUS "INFO" "  - Password saved to: /root/.grub_password"
    HARDN_STATUS "WARNING" "Remember to set BIOS/UEFI password to prevent boot order changes"
    HARDN_STATUS "WARNING" "Normal booting works without password - password only required for GRUB menu editing"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi