#!/bin/bash

source "$(cd "$(dirname "$0")/.." && pwd)/functions.sh"

# HARDN STIG Tool: kernel.sh
# Purpose: Apply STIG-compliant kernel security parameters
# Location: /src/tools/stig/kernel.sh

check_root
log_tool_execution "stig/kernel.sh"

configure_stig_kernel() {
    HARDN_STATUS "info" "Setting up STIG-compliant kernel parameters..."
    
    # Create STIG kernel configuration
    cat > /etc/sysctl.d/stig-kernel.conf << 'EOF'
# STIG-compliant kernel security parameters
kernel.randomize_va_space = 2
kernel.exec-shield = 1
kernel.panic = 10
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
EOF

    
    # Additional hardening parameters
kernel.modules_disabled = 1
kernel.kexec_load_disabled = 1
EOF

    HARDN_STATUS "pass" "STIG kernel configuration file created"
    
    # Apply the new sysctl settings
    HARDN_STATUS "info" "Applying sysctl settings..."
    if sysctl --system >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Sysctl settings applied successfully"
    else
        HARDN_STATUS "warning" "Some sysctl settings may not have applied correctly"
    fi

    # Blacklist unnecessary kernel modules
    HARDN_STATUS "info" "Blacklisting unnecessary kernel modules..."
    cat > /etc/modprobe.d/hardn-blacklist.conf << 'EOF'
# Blacklist unnecessary filesystems and modules
install cramfs /bin/false
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
install squashfs /bin/false
install udf /bin/false
install usb-storage /bin/false
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF

    HARDN_STATUS "pass" "Kernel modules blacklisted"
    
    # Update initramfs
    HARDN_STATUS "info" "Updating initramfs..."
    if update-initramfs -u >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Initramfs updated successfully"
    else
        HARDN_STATUS "warning" "Failed to update initramfs"
    fi
    
    HARDN_STATUS "pass" "STIG kernel security configuration completed"
}

main() {
    configure_stig_kernel
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
