#!/bin/bash

# Source the functions.sh file for common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../functions.sh"

# STIG Virtual Address Space Randomization
# Implements DISA STIG requirements for ASLR (Address Space Layout Randomization)

stig_set_randomize_va_space() {
    HARDN_STATUS "INFO" "Configuring kernel address space layout randomization (ASLR)"
    
    local sysctl_conf="/etc/sysctl.d/99-hardn-aslr.conf"
    
    # Backup existing configuration if it exists
    if [ -f "$sysctl_conf" ]; then
        backup_file "$sysctl_conf"
    fi
    
    # Create ASLR configuration
    cat <<EOF > "$sysctl_conf"
# STIG Address Space Layout Randomization (ASLR) Configuration
# Enable full ASLR for enhanced security against buffer overflow attacks

# Enable ASLR (2 = full randomization)
kernel.randomize_va_space = 2

# Additional memory protection settings
kernel.exec-shield = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1

# Stack protection
kernel.stackprotector = 1

# Prevent core dumps from setuid programs
fs.suid_dumpable = 0

# Restrict access to kernel logs
kernel.printk = 3 4 1 3
EOF
    
    # Set proper permissions
    chmod 644 "$sysctl_conf"
    chown root:root "$sysctl_conf"
    
    HARDN_STATUS "INFO" "ASLR configuration file created"
    
    # Apply ASLR settings immediately
    HARDN_STATUS "INFO" "Applying ASLR settings"
    if sysctl -w kernel.randomize_va_space=2; then
        HARDN_STATUS "PASS" "ASLR enabled successfully"
    else
        HARDN_STATUS "ERROR" "Failed to enable ASLR"
        return 1
    fi
    
    # Apply all sysctl settings from the configuration file
    HARDN_STATUS "INFO" "Applying all memory protection settings"
    if sysctl -p "$sysctl_conf"; then
        HARDN_STATUS "PASS" "Memory protection settings applied successfully"
    else
        HARDN_STATUS "WARNING" "Some memory protection settings may not have been applied"
    fi
    
    # Verify ASLR is properly configured
    HARDN_STATUS "INFO" "Verifying ASLR configuration"
    local current_aslr
    current_aslr=$(sysctl -n kernel.randomize_va_space 2>/dev/null)
    
    if [ "$current_aslr" = "2" ]; then
        HARDN_STATUS "PASS" "ASLR is properly configured (level 2 - full randomization)"
    elif [ "$current_aslr" = "1" ]; then
        HARDN_STATUS "WARNING" "ASLR is partially enabled (level 1 - limited randomization)"
    elif [ "$current_aslr" = "0" ]; then
        HARDN_STATUS "ERROR" "ASLR is disabled (level 0)"
        return 1
    else
        HARDN_STATUS "WARNING" "ASLR status unknown: $current_aslr"
    fi
    
    # Display current memory protection status
    HARDN_STATUS "INFO" "Current memory protection settings:"
    HARDN_STATUS "INFO" "  - ASLR Level: $(sysctl -n kernel.randomize_va_space 2>/dev/null || echo 'unknown')"
    HARDN_STATUS "INFO" "  - Kernel Pointer Restriction: $(sysctl -n kernel.kptr_restrict 2>/dev/null || echo 'unknown')"
    HARDN_STATUS "INFO" "  - Dmesg Restriction: $(sysctl -n kernel.dmesg_restrict 2>/dev/null || echo 'unknown')"
    HARDN_STATUS "INFO" "  - Ptrace Scope: $(sysctl -n kernel.yama.ptrace_scope 2>/dev/null || echo 'unknown')"
    
    HARDN_STATUS "PASS" "STIG ASLR configuration completed"
}

main() {
    check_root
    log_tool_execution "va_space.sh" "STIG ASLR configuration"
    
    HARDN_STATUS "INFO" "Starting STIG ASLR configuration"
    
    stig_set_randomize_va_space
    
    HARDN_STATUS "PASS" "STIG ASLR configuration completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi