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
    
    echo "✅ Debian-based system detected"
}

update_system() {
    echo "📦 Updating system packages..."
    if apt update && apt upgrade -y; then
        echo "✅ System updated successfully"
    else
        echo "⚠️  System update encountered issues, continuing..."
    fi
}

install_dependencies() {
    echo "📋 Installing build dependencies..."
    apt install -y curl wget ca-certificates gnupg lsb-release
}

install_hardn_package() {
    echo "🔽 Downloading and installing HARDN-XDR package..."
    
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "${temp_dir}"
    
    # Try to download from GitHub releases first
    local github_url="https://github.com/OpenSource-For-Freedom/HARDN/releases/download/v${HARDN_VERSION}/hardn-xdr_${HARDN_VERSION}-1_all.deb"
    
    if curl -L -f "${github_url}" -o "hardn-xdr_${HARDN_VERSION}-1_all.deb"; then
        echo "✅ Downloaded HARDN-XDR package from GitHub releases"
    else
        echo "⚠️  GitHub release not found, building from source..."
        
        # Install build dependencies
        apt install -y git debhelper-compat devscripts build-essential
        
        # Clone repository and build package
        git clone https://github.com/OpenSource-For-Freedom/HARDN.git
        cd HARDN
        dpkg-buildpackage -us -uc -b
        cd ..
        mv hardn-xdr_*.deb "hardn-xdr_${HARDN_VERSION}-1_all.deb"
    fi
    
    # Install the package
    echo "📦 Installing HARDN-XDR package..."
    if dpkg -i "hardn-xdr_${HARDN_VERSION}-1_all.deb"; then
        echo "✅ HARDN-XDR package installed successfully"
    else
        echo "🔧 Fixing dependency issues..."
        apt-get install -f -y
        echo "✅ Dependencies resolved"
    fi
    
    # Clean up
    cd /
    rm -rf "${temp_dir}"
}

show_completion() {
    cat << 'EOF'

🎉 HARDN-XDR Installation Complete!

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

⚠️  IMPORTANT: HARDN-XDR makes significant system changes.
   Always test in a non-production environment first.

EOF
}

main() {
    echo "🔒 HARDN-XDR v${HARDN_VERSION} Installation Script"
    echo "=============================================="
    
    check_root
    check_system
    update_system
    install_dependencies
    install_hardn_package
    show_completion
}

main "$@"
