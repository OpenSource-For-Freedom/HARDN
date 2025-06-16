#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: qemu.sh
# Purpose: Install and configure QEMU virtualization with security hardening
# Location: /src/tools/qemu.sh

check_root
log_tool_execution "qemu.sh"

install_and_configure_qemu() {
    HARDN_STATUS "info" "Installing and configuring QEMU virtualization..."
    
    # Check if QEMU is already installed
    if is_package_installed qemu-system-x86; then
        HARDN_STATUS "pass" "QEMU is already installed"
    else
        HARDN_STATUS "info" "Installing QEMU packages..."
        local qemu_packages="qemu-system-x86 qemu-utils qemu-kvm"
        if install_package $qemu_packages; then
            HARDN_STATUS "pass" "QEMU packages installed successfully"
        else
            HARDN_STATUS "error" "Failed to install QEMU packages"
            return 1
        fi
    fi

    HARDN_STATUS "info" "Configuring QEMU security settings..."
    
    # Check for KVM support
    if [ -e /dev/kvm ]; then
        HARDN_STATUS "pass" "KVM acceleration is available"
        
        # Set proper permissions for KVM device
        chown root:kvm /dev/kvm
        chmod 660 /dev/kvm
        
        # Add user to kvm group if not already there
        if [ -n "$SUDO_USER" ]; then
            usermod -a -G kvm "$SUDO_USER"
            HARDN_STATUS "pass" "Added user $SUDO_USER to kvm group"
        fi
    else
        HARDN_STATUS "warning" "KVM acceleration is not available (running in VM or CPU doesn't support virtualization)"
    fi
    
    # Create QEMU configuration directory
    mkdir -p /etc/qemu
    
    # Create secure QEMU bridge configuration
    cat > /etc/qemu/bridge.conf << 'EOF'
# QEMU bridge configuration
# Allow qemu to use virbr0 bridge
allow virbr0
EOF

    # Set proper permissions
    chown root:root /etc/qemu/bridge.conf
    chmod 640 /etc/qemu/bridge.conf
    HARDN_STATUS "pass" "QEMU bridge configuration created"
    
    # Create QEMU user if it doesn't exist
    if ! id -u qemu >/dev/null 2>&1; then
        useradd -r -s /bin/false -d /var/lib/qemu qemu
        HARDN_STATUS "pass" "Created qemu user"
    fi
    
    # Create QEMU directories with proper permissions
    mkdir -p /var/lib/qemu
    mkdir -p /var/log/qemu
    chown qemu:qemu /var/lib/qemu
    chown qemu:qemu /var/log/qemu
    chmod 755 /var/lib/qemu
    chmod 755 /var/log/qemu
    HARDN_STATUS "pass" "QEMU directories configured with proper permissions"
    
    # Configure AppArmor profile for QEMU if AppArmor is available
    if command_exists aa-status; then
        HARDN_STATUS "info" "Configuring AppArmor profile for QEMU..."
        
        # Enable QEMU AppArmor profiles
        if [ -f /etc/apparmor.d/usr.bin.qemu-system-x86_64 ]; then
            aa-enforce /etc/apparmor.d/usr.bin.qemu-system-x86_64 2>/dev/null || true
        fi
        
        if [ -f /etc/apparmor.d/abstractions/libvirt-qemu ]; then
            systemctl reload apparmor 2>/dev/null || true
        fi
    fi
    
    # Create logrotate configuration for QEMU
    cat > /etc/logrotate.d/qemu << 'EOF'
/var/log/qemu/*.log {
    weekly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
    create 640 qemu qemu
    su qemu qemu
}
EOF

    # Create a script to check QEMU/KVM capabilities
    cat > /usr/local/bin/qemu-check.sh << 'EOF'
#!/bin/bash
# QEMU/KVM capability check script

echo "=== QEMU/KVM System Check ==="

# Check KVM support
if [ -e /dev/kvm ]; then
    echo "✓ KVM device available: /dev/kvm"
    ls -la /dev/kvm
else
    echo "✗ KVM device not available"
fi

# Check CPU virtualization support
if grep -E '(vmx|svm)' /proc/cpuinfo >/dev/null; then
    echo "✓ CPU supports virtualization"
    grep -E '(vmx|svm)' /proc/cpuinfo | head -1
else
    echo "✗ CPU does not support virtualization"
fi

# Check QEMU version
if command -v qemu-system-x86_64 >/dev/null; then
    echo "✓ QEMU installed:"
    qemu-system-x86_64 --version | head -1
else
    echo "✗ QEMU not installed"
fi

# Check libvirt connection
if command -v virsh >/dev/null; then
    echo "✓ Testing libvirt connection:"
    virsh version 2>/dev/null || echo "✗ libvirt connection failed"
            aa-enforce /etc/apparmor.d/usr.bin.qemu-system-x86_64 2>/dev/null || true
            HARDN_STATUS "pass" "QEMU AppArmor profile enabled"
        else
            HARDN_STATUS "info" "QEMU AppArmor profile not found, skipping"
        fi
    else
        HARDN_STATUS "info" "AppArmor not available, skipping profile configuration"
    fi
    
    # Create QEMU capability check script
    cat > /usr/local/bin/qemu-check.sh << 'EOF'
#!/bin/bash
echo "=== QEMU Capability Check ==="
echo "KVM Support:"
if [ -e /dev/kvm ]; then
    echo "✓ /dev/kvm exists"
    ls -l /dev/kvm
else
    echo "✗ KVM not available"
fi

echo "QEMU Version:"
qemu-system-x86_64 --version 2>/dev/null || echo "✗ QEMU not found"

echo "libvirt Status:"
if systemctl is-active --quiet libvirtd 2>/dev/null; then
    echo "✓ libvirtd running"
else
    echo "✗ libvirt not available"
fi

echo "=== End Check ==="
EOF

    chmod +x /usr/local/bin/qemu-check.sh
    
    HARDN_STATUS "pass" "QEMU installed and configured successfully"
    HARDN_STATUS "info" "Running QEMU capability check:"
    
    # Run capability check
    /usr/local/bin/qemu-check.sh
    
    HARDN_STATUS "info" "Note: You may need to log out and back in for group membership to take effect"
}

main() {
    install_and_configure_qemu
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
