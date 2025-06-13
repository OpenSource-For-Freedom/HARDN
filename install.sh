#!/bin/bash

# HARDN-XDR Installation Script
# Updated for Debian package installation
# Author: Christopher Bingham

set -e

HARDN_VERSION="2.0.0"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script requires root privileges. Please run with sudo."
        exit 1
    fi
}

check_system() {
    if [[ ! -f /etc/debian_version ]]; then
        echo "Error: This system is not Debian-based. HARDN-XDR requires Debian 12+ or Ubuntu 24.04+."
        exit 1
    fi
    
    echo "OK Debian-based system detected"
}

update_system() {
    echo "📦 Updating system packages..."
    if apt update && apt upgrade -y; then
        echo "OK System updated successfully"
    else
        echo "WARNING System update encountered issues, continuing..."
    fi
}

install_dependencies() {
    echo "📦 Installing dependencies..."
    
    # Install dependencies
    apt-get update
    apt-get install -y apparmor-utils apparmor-profiles
    
    echo "Installing build dependencies..."
    apt install -y curl wget ca-certificates gnupg lsb-release
}

install_hardn_package() {
    echo "🔽 Downloading and installing HARDN-XDR package..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "${temp_dir}"
    
    # Try to download from GitHub releases first with retry logic
    local github_url="https://github.com/OpenSource-For-Freedom/HARDN/releases/download/v${HARDN_VERSION}/hardn-xdr_${HARDN_VERSION}-1_all.deb"
    
    MAX_RETRIES=3
    COUNT=0
    DOWNLOADED=false
    
    while [ $COUNT -lt $MAX_RETRIES ]; do
        if curl -L -f "${github_url}" -o "hardn-xdr_${HARDN_VERSION}-1_all.deb"; then
            echo "OK Downloaded HARDN-XDR package from GitHub releases"
            DOWNLOADED=true
            break
        fi
        COUNT=$((COUNT+1))
        echo "Retry $COUNT/$MAX_RETRIES: GitHub download failed, retrying in 5 seconds..."
        sleep 5
    done
    
    if [ "$DOWNLOADED" = false ]; then
        echo "WARNING GitHub release not found after $MAX_RETRIES attempts, building from source..."
        
        # Install build dependencies
        apt install -y git debhelper-compat devscripts build-essential
        
        # Clone repository with retry logic
        COUNT=0
        while [ $COUNT -lt $MAX_RETRIES ]; do
            if git clone https://github.com/OpenSource-For-Freedom/HARDN.git; then
                break
            fi
            COUNT=$((COUNT+1))
            echo "Retry $COUNT/$MAX_RETRIES: Git clone failed, retrying in 5 seconds..."
            sleep 5
        done
        
        if [ $COUNT -eq $MAX_RETRIES ]; then
            echo "ERROR: Failed to clone repository after $MAX_RETRIES attempts."
            exit 1
        fi
        
        cd HARDN
        dpkg-buildpackage -us -uc -b
        cd ..
        mv hardn-xdr_*.deb "hardn-xdr_${HARDN_VERSION}-1_all.deb"
    fi
    
    # Install the package
    echo "📦 Installing HARDN-XDR package..."
    if dpkg -i "hardn-xdr_${HARDN_VERSION}-1_all.deb"; then
        echo "OK HARDN-XDR package installed successfully"
    else
        echo "Package installation failed, fixing dependencies..."
        apt-get install -f -y
        echo "OK Dependencies resolved"
    fi
    
    # Verify installation
    if ! command -v hardn > /dev/null 2>&1; then
        echo "ERROR: hardn command not found after installation"
        
        # Check package contents
        dpkg -L hardn-xdr | grep bin/ || true
        
        # Add the installation directory to PATH
        export PATH="$PATH:/usr/bin"
        echo "Updated PATH: $PATH"
        
        # Try again
        if ! command -v hardn > /dev/null 2>&1; then
            echo "ERROR: hardn command still not found. Installation may have failed."
            exit 1
        fi
    fi
    
    # Clean up
    cd /
    rm -rf "${temp_dir}"
}

create_system_groups() {
    echo "🔧 Checking system groups..."
    
    # Check and create groups if necessary
    if ! getent group systemd-network >/dev/null 2>&1; then
        groupadd -r systemd-network
        echo "Created systemd-network group"
    else
        echo "systemd-network group already exists"
    fi

    if ! getent group systemd-journal >/dev/null 2>&1; then
        groupadd -r systemd-journal  
        echo "Created systemd-journal group"
    else
        echo "systemd-journal group already exists"
    fi
}

handle_resolv_conf() {
    echo "🔧 Handling resolv.conf configuration..."
    
    # Backup and create symlink
    if [[ -f /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
        mv /etc/resolv.conf "/tmp/resolv.conf-backup.$(date +%Y%m%d%H%M%S)" || echo "Failed to back up /etc/resolv.conf"
        echo "Backed up original resolv.conf"
    fi
    
    # Create symlink if the target exists
    if [[ -f /run/systemd/resolve/stub-resolv.conf ]]; then
        ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || echo "Symlink creation failed, continuing..."
        echo "Created systemd-resolved symlink"
    else
        echo "systemd-resolved not available, skipping symlink creation"
    fi
}

show_completion() {
    cat << 'EOF'

HARDN-XDR Installation Complete!

Next steps:
1. Run system hardening:
   sudo hardn setup

2. Check system status:
   hardn status

3. Run security audit:
   sudo hardn audit

4. View help:
   hardn --help

For documentation and support:
https://github.com/OpenSource-For-Freedom/HARDN

WARNING IMPORTANT: HARDN-XDR makes significant system changes.
   Always test in a non-production environment first.

EOF
}

main() {
    echo "🔒 HARDN-XDR v${HARDN_VERSION} Installation Script"
    echo "=============================================="
    
    check_root
    check_system
    update_system
    create_system_groups
    handle_resolv_conf
    install_dependencies
    install_hardn_package
    show_completion
}

main "$@"
