#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: install_pkgdeps.sh
# Purpose: Install package dependencies for HARDN security tools
# Location: /src/tools/install_pkgdeps.sh

check_root
log_tool_execution "install_pkgdeps.sh"

HARDN_STATUS "info" "Installing HARDN package dependencies..."

# Core dependencies
local deps=(
    wget curl git gawk mariadb-common mysql-common policycoreutils
    unixodbc-common firejail python3-pyqt6 fonts-liberation
)

# Install each dependency
for pkg in "${deps[@]}"; do
    if install_package "$pkg"; then
        HARDN_STATUS "pass" "Successfully installed $pkg"
    else
        HARDN_STATUS "warning" "Failed to install $pkg - continuing with other packages"
    fi
done

# Read additional dependencies from progs.csv if available
if [ -f "/etc/hardn/progs.csv" ]; then
    HARDN_STATUS "info" "Reading additional dependencies from progs.csv..."
    while IFS=',' read -r package category description; do
        # Skip header line and empty lines
        [[ "$package" == "package" ]] && continue
        [[ -z "$package" ]] && continue
        
        if ! is_package_installed "$package"; then
            HARDN_STATUS "info" "Installing $package ($category: $description)"
            if install_package "$package"; then
                HARDN_STATUS "pass" "Successfully installed $package"
            else
                HARDN_STATUS "warning" "Failed to install $package"
            fi
        else
            HARDN_STATUS "pass" "$package already installed"
        fi
    done < "/etc/hardn/progs.csv"
else
    HARDN_STATUS "warning" "progs.csv not found at /etc/hardn/progs.csv"
fi

HARDN_STATUS "pass" "Package dependencies installation completed"