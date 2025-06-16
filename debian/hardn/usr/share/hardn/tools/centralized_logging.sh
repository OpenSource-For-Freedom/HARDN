#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: centralized_logging.sh
# Purpose: Centralized Logging Utility for HARDN tools
# Location: /src/tools/centralized_logging.sh

check_root
log_tool_execution "centralized_logging.sh"

setup_centralized_logging() {
    HARDN_STATUS "info" "Setting up centralized logging system..."
    
    # Create log directories
    local log_dirs=(
        "/var/log/hardn"
        "/var/log/hardn/security"
        "/var/log/hardn/tools"
        "/var/log/hardn/stig"
        "/var/log/hardn/monitoring"
    )
    
    for dir in "${log_dirs[@]}"; do
        if mkdir -p "$dir"; then
            chmod 750 "$dir"
            HARDN_STATUS "pass" "Created log directory: $dir"
        else
            HARDN_STATUS "error" "Failed to create log directory: $dir"
            return 1
        fi
    done
    
    # Install rsyslog if not present
    if ! is_package_installed rsyslog; then
        HARDN_STATUS "info" "Installing rsyslog..."
        if install_package rsyslog; then
            HARDN_STATUS "pass" "rsyslog installed successfully"
        else
            HARDN_STATUS "error" "Failed to install rsyslog"
            return 1
        fi
    else
        HARDN_STATUS "pass" "rsyslog already installed"
    fi
    
    # Configure rsyslog for HARDN
    HARDN_STATUS "info" "Configuring rsyslog for HARDN logging..."
    cat > /etc/rsyslog.d/10-hardn.conf << 'EOF'
# HARDN Security Tools Logging Configuration

# HARDN main log
:programname, isequal, "hardn" /var/log/hardn/hardn.log
& stop

# HARDN tools logging
:msg, contains, "[HARDN]" /var/log/hardn/hardn-tools.log
& stop

# Security events
local0.* /var/log/hardn/security/security.log
local1.* /var/log/hardn/tools/tools.log
local2.* /var/log/hardn/stig/stig.log
local3.* /var/log/hardn/monitoring/monitoring.log

# Stop processing after HARDN logs
& stop
EOF
    
    # Install logrotate if not present
    if ! is_package_installed logrotate; then
        HARDN_STATUS "info" "Installing logrotate..."
        if install_package logrotate; then
            HARDN_STATUS "pass" "logrotate installed successfully"
        else
            HARDN_STATUS "error" "Failed to install logrotate"
            return 1
        fi
    else
        HARDN_STATUS "pass" "logrotate already installed"
    fi
    
    # Configure logrotate for HARDN logs
    HARDN_STATUS "info" "Configuring log rotation for HARDN logs..."
    cat > /etc/logrotate.d/hardn << 'EOF'
/var/log/hardn/*.log /var/log/hardn/*/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root root
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    
    # Restart rsyslog to apply configuration
    if systemctl restart rsyslog; then
        HARDN_STATUS "pass" "rsyslog restarted with new configuration"
    else
        HARDN_STATUS "error" "Failed to restart rsyslog"
        return 1
    fi
    
    # Create centralized logging functions
    cat > /usr/local/bin/hardn-log << 'EOF'
#!/bin/bash
# HARDN Centralized Logging Function

hardn_log() {
    local level="$1"
    local component="$2" 
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            logger -p local0.info -t "hardn-$component" "[$timestamp] [INFO] $message"
            ;;
        "WARN")
            logger -p local0.warning -t "hardn-$component" "[$timestamp] [WARNING] $message"
            ;;
        "ERROR")
            logger -p local0.err -t "hardn-$component" "[$timestamp] [ERROR] $message"
            ;;
        "DEBUG")
            logger -p local0.debug -t "hardn-$component" "[$timestamp] [DEBUG] $message"
            ;;
        *)
            logger -p local0.info -t "hardn-$component" "[$timestamp] [UNKNOWN] $message"
            ;;
    esac
}

# Export function for use by other scripts
export -f hardn_log
EOF
    
    chmod +x /usr/local/bin/hardn-log
    HARDN_STATUS "pass" "Created centralized logging function at /usr/local/bin/hardn-log"
    
    HARDN_STATUS "pass" "Centralized logging system setup completed"
}

main() {
    setup_centralized_logging
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi