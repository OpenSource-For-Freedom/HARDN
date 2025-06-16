#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: aide.sh
# Purpose: Setup and initialize AIDE (Advanced Intrusion Detection Environment)  
# Location: /src/tools/aide.sh

check_root
log_tool_execution "aide.sh"

HARDN_STATUS "info" "Installing and initializing AIDE (Advanced Intrusion Detection Environment)..."

# Install AIDE if not present
if ! is_package_installed aide; then
    HARDN_STATUS "info" "Installing aide package..."
    if install_package aide; then
        HARDN_STATUS "pass" "AIDE package installed successfully"
    else
        HARDN_STATUS "error" "Failed to install AIDE package"
        exit 1
    fi
else
    HARDN_STATUS "pass" "AIDE package already installed"
fi

# Initialize AIDE database
if [ -f /etc/aide/aide.conf ]; then
    HARDN_STATUS "info" "Initializing AIDE database..."
    if aideinit || aide --init; then
        HARDN_STATUS "pass" "AIDE database initialized successfully"
        # Move new database into place if needed
        if [ -f /var/lib/aide/aide.db.new ]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
            HARDN_STATUS "pass" "AIDE database moved into place"
        fi
    else
        HARDN_STATUS "error" "Failed to initialize AIDE database"
        exit 1
    fi
else
    HARDN_STATUS "error" "/etc/aide/aide.conf not found. Cannot initialize AIDE"
    exit 1
fi

# Set up AIDE cron job for daily checks
HARDN_STATUS "info" "Setting up AIDE cron job for daily integrity checks..."
cat > /etc/cron.daily/aide << 'EOF'
#!/bin/bash
# Daily AIDE integrity check
/usr/bin/aide --check 2>&1 | logger -t aide
EOF
chmod +x /etc/cron.daily/aide
HARDN_STATUS "pass" "AIDE daily cron job configured"

HARDN_STATUS "pass" "AIDE setup complete. You can run 'aide --check' to verify system integrity"
