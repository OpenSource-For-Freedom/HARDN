#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: libvirt.sh
# Purpose: Install and configure libvirt virtualization platform securely
# Location: /src/tools/libvirt.sh

check_root
log_tool_execution "libvirt.sh"

install_and_configure_libvirt() {
    HARDN_STATUS "info" "Installing and configuring libvirt virtualization platform..."
    
    # Check if libvirt packages are already installed
    if is_package_installed libvirt-daemon-system && is_package_installed libvirt-clients; then
        HARDN_STATUS "pass" "libvirt packages are already installed"
    else
        HARDN_STATUS "info" "Installing libvirt packages..."
        local libvirt_packages="libvirt-daemon-system libvirt-clients libvirt-dev"
        if install_package $libvirt_packages; then
            HARDN_STATUS "pass" "libvirt packages installed successfully"
        else
            HARDN_STATUS "error" "Failed to install libvirt packages"
            return 1
        fi
    fi

    HARDN_STATUS "info" "Configuring libvirt security settings..."
    
    # Backup original configurations
    backup_file "/etc/libvirt/libvirtd.conf"
    backup_file "/etc/libvirt/qemu.conf"
    
    # Configure libvirtd security settings
    cat >> /etc/libvirt/libvirtd.conf << 'EOF'

# HARDN Security Configuration
# Listen only on local socket for security
listen_tls = 0
listen_tcp = 0
unix_sock_group = "libvirt"
unix_sock_ro_perms = "0777"
unix_sock_rw_perms = "0770"
unix_sock_admin_perms = "0700"
auth_unix_ro = "none"
auth_unix_rw = "none"

# Enable logging
log_level = 2
log_outputs = "2:file:/var/log/libvirt/libvirtd.log"

# Security driver
security_driver = "apparmor"
EOF

    # Configure QEMU security settings
    cat >> /etc/libvirt/qemu.conf << 'EOF'

# HARDN QEMU Security Configuration
# Run VMs as unprivileged user
user = "libvirt-qemu"
group = "libvirt-qemu"

# Security driver
security_driver = "apparmor"
security_default_confined = 1
security_require_confined = 1

# Memory settings
memory_backing_dir = "/var/lib/libvirt/qemu/ram"

# Clear emulator capabilities
clear_emulator_capabilities = 1

# Set process limits
max_processes = 1024
max_files = 32768

# Disable spice graphics by default
spice_listen = "127.0.0.1"
spice_tls = 1

# VNC security
vnc_listen = "127.0.0.1"
vnc_tls = 1
EOF

    # Create memory backing directory
    mkdir -p /var/lib/libvirt/qemu/ram
    chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/qemu/ram
    chmod 755 /var/lib/libvirt/qemu/ram
    
    # Configure libvirt log directory
    mkdir -p /var/log/libvirt
    chown root:root /var/log/libvirt
    chmod 755 /var/log/libvirt
    
    HARDN_STATUS "pass" "libvirt security configuration applied"
    
    # Create logrotate configuration for libvirt
    cat > /etc/logrotate.d/libvirt << 'EOF'
/var/log/libvirt/*.log {
    weekly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
    create 640 root root
    postrotate
        /bin/kill -USR1 `cat /var/run/libvirtd.pid 2> /dev/null` 2> /dev/null || true
    endscript
}
EOF

    # Add current user to libvirt group if not already there
    if [ -n "$SUDO_USER" ]; then
        usermod -a -G libvirt "$SUDO_USER"
        HARDN_STATUS "pass" "Added user $SUDO_USER to libvirt group"
    fi
    
    # Enable and start libvirt services
    if systemctl enable --now libvirtd && systemctl enable --now virtlogd; then
        HARDN_STATUS "pass" "libvirt services enabled and started"
    else
        HARDN_STATUS "warning" "Some libvirt services may not have started properly"
    fi
    
    HARDN_STATUS "info" "Configuring secure default network..."
    
    # Create secure network configuration
    cat > /tmp/secure-default.xml << 'EOF'
<network>
  <name>default</name>
  <bridge name="virbr0"/>
  <forward mode="nat"/>
  <ip address="192.168.122.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.122.2" end="192.168.122.254"/>
    </dhcp>
  </ip>
</network>
EOF

    # Define and start the network
    virsh net-define /tmp/secure-default.xml 2>/dev/null || true
    virsh net-autostart default 2>/dev/null || true
    virsh net-start default 2>/dev/null || true
    
    # Clean up temporary file
    rm -f /tmp/secure-default.xml
    
    HARDN_STATUS "pass" "libvirt installed and configured successfully"
    
    # Display status information
    HARDN_STATUS "info" "libvirt service status:"
    systemctl status libvirtd --no-pager -l | head -10
    
    HARDN_STATUS "info" "Available networks:"
    virsh net-list --all 2>/dev/null || echo "No networks configured yet"
    
    HARDN_STATUS "info" "Note: You may need to log out and back in for group membership to take effect"
}

main() {
    install_and_configure_libvirt
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
