#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: suricata.sh
# Purpose: Install and configure Suricata IDS/IPS
# Location: /src/tools/suricata.sh

check_root
log_tool_execution "suricata.sh"

HARDN_STATUS "info" "Setting up Suricata IDS/IPS..."

# Try to install Suricata from package first
if ! is_package_installed suricata; then
    HARDN_STATUS "info" "Installing Suricata from repository..."
    if install_package suricata; then
        HARDN_STATUS "pass" "Suricata installed from repository"
    else
        HARDN_STATUS "warning" "Repository installation failed, attempting source installation..."
        
        # Install build dependencies
        HARDN_STATUS "info" "Installing Suricata build dependencies..."
        local build_deps=(
            build-essential libpcap-dev libnet1-dev libyaml-0-2 libyaml-dev 
            zlib1g zlib1g-dev libcap-ng-dev libmagic-dev libjansson-dev 
            libnss3-dev liblz4-dev libtool libnfnetlink-dev libevent-dev 
            pkg-config libhiredis-dev python3 python3-yaml python3-setuptools 
            python3-pip python3-dev rustc cargo wget
        )
        
        apt-get update
        for pkg in "${build_deps[@]}"; do
            if ! install_package "$pkg"; then
                HARDN_STATUS "warning" "Failed to install build dependency: $pkg"
            fi
        done
        
        local suricata_version="7.0.0"
        local download_url="https://www.suricata-ids.org/download/releases/suricata-${suricata_version}.tar.gz"
        local download_dir="/tmp/suricata_install"
        local tar_file="$download_dir/suricata-${suricata_version}.tar.gz"
        local extracted_dir="suricata-${suricata_version}"

        mkdir -p "$download_dir"
        cd "$download_dir" || { 
            HARDN_STATUS "error" "Cannot change directory to $download_dir"
            exit 1
        }

        HARDN_STATUS "info" "Downloading Suricata source..."
        if wget -q "$download_url" -O "$tar_file"; then
            HARDN_STATUS "pass" "Download successful"
            
            HARDN_STATUS "info" "Extracting source..."
            if tar -xzf "$tar_file" -C "$download_dir"; then
                HARDN_STATUS "pass" "Extraction successful"

                if [[ -d "$download_dir/$extracted_dir" ]]; then
                    cd "$download_dir/$extracted_dir" || {
                        HARDN_STATUS "error" "Cannot change directory to extracted folder"
                        exit 1
                    }

                    HARDN_STATUS "info" "Configuring Suricata build..."
                    if ./configure \
                        --prefix=/usr \
                        --sysconfdir=/etc \
                        --localstatedir=/var \
                        --disable-gccmarch-native \
                        --enable-lua \
                        --enable-geoip; then
                        HARDN_STATUS "pass" "Configure successful"

                        HARDN_STATUS "info" "Building Suricata..."
                        if make -j$(nproc); then
                            HARDN_STATUS "pass" "Build successful"
                            
                            HARDN_STATUS "info" "Installing Suricata..."
                            if make install; then
                                HARDN_STATUS "pass" "Suricata installed from source"
                                ldconfig || true
                            else
                                HARDN_STATUS "error" "Installation failed"
                                exit 1
                            fi
                        else
                            HARDN_STATUS "error" "Build failed"
                            exit 1
                        fi
                    else
                        HARDN_STATUS "error" "Configure failed"
                        exit 1
                    fi
                else
                    HARDN_STATUS "error" "Extracted directory not found"
                    exit 1
                fi
            else
                HARDN_STATUS "error" "Extraction failed"
                exit 1
            fi
        else
            HARDN_STATUS "error" "Download failed"
            exit 1
        fi
        
        # Cleanup
        cd /
        rm -rf "$download_dir"
        HARDN_STATUS "info" "Source installation cleanup completed"
    fi
else
    HARDN_STATUS "pass" "Suricata package already installed"
fi

# Configure Suricata if installed
if command_exists suricata; then
    HARDN_STATUS "info" "Configuring Suricata..."

    # Ensure configuration directory exists
    if [ ! -d /etc/suricata ]; then
        HARDN_STATUS "info" "Creating /etc/suricata directory..."
        mkdir -p /etc/suricata
    fi

    # Create user and group if they don't exist
    if ! id -u suricata >/dev/null 2>&1; then
        HARDN_STATUS "info" "Creating suricata user..."
        useradd --system --no-create-home --shell /bin/false suricata
        HARDN_STATUS "pass" "Suricata user created"
    fi

    # Create log directory
    mkdir -p /var/log/suricata
    chown suricata:suricata /var/log/suricata

    # Create rules directory
    mkdir -p /var/lib/suricata/rules
    chown suricata:suricata /var/lib/suricata/rules

    # Install/update suricata-update for rule management
    if ! command_exists suricata-update; then
        HARDN_STATUS "info" "Installing suricata-update..."
        if pip3 install --upgrade pip && pip3 install --upgrade suricata-update; then
            HARDN_STATUS "pass" "suricata-update installed successfully"
        else
            HARDN_STATUS "warning" "Failed to install suricata-update via pip3"
        fi
    fi

    # Update rules if suricata-update is available
    if command_exists suricata-update; then
        HARDN_STATUS "info" "Updating Suricata rules..."
        if suricata-update; then
            HARDN_STATUS "pass" "Suricata rules updated successfully"
        else
            HARDN_STATUS "warning" "Suricata rules update failed"
        fi
    fi

    # Enable and start service
    if enable_service suricata; then
        HARDN_STATUS "pass" "Suricata service enabled and started"
    else
        HARDN_STATUS "warning" "Failed to enable/start Suricata service"
    fi

    # Test configuration if config file exists
    if [ -f /etc/suricata/suricata.yaml ]; then
        HARDN_STATUS "info" "Testing Suricata configuration..."
        if suricata -T -c /etc/suricata/suricata.yaml; then
            HARDN_STATUS "pass" "Suricata configuration test passed"
        else
            HARDN_STATUS "warning" "Suricata configuration test failed"
        fi
    else
        HARDN_STATUS "info" "No configuration file found, using default settings"
    fi

else
    HARDN_STATUS "error" "Suricata command not found after installation attempt"
fi

HARDN_STATUS "pass" "Suricata setup completed"